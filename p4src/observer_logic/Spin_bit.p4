/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	Author: Ike Kunze
	E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

// Struct for the threshold mechanism
struct struct_spin_threshold_counter {
    bit<8> threshold_counter;
    bit<8> phase;
}

control SpinBit(
    inout ingress_headers_t                       hdr,
    inout ingress_metadata_t                      meta,
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md)
{

    /* This register tracks the most recent timestamps of the different flows

    Timer wraparound protection (Pt1): 
        - if 'current timestamp' smaller than 'previous timestamp' (wraparound case): compute 'previous timestamp' - 'current timestamp'
        - otherwise (non-wraparound case): compute 'current timestamp' - 'previous timestamp'
    */ 
    Register<rtt_t, flow_id_t>(NUM_FLOWS) spin_delay_tracker;
    RegisterAction<rtt_t, flow_id_t, rtt_t>(spin_delay_tracker) update_timestamp = { 
        void apply(inout rtt_t register_data, out rtt_t result) {
            if (meta.current_time < register_data){
                result = register_data - meta.current_time;
            } else{
                result = meta.current_time - register_data;
            }
            register_data = meta.current_time; 
        } 
    };

    /* This register is a duplicate of spin_delay_tracker.

    Time wraparound protection (Pt2):
        - Using the same if-logic as 'spin_delay_tracker', this register returns 1 in case of a wraparound, 0 otherwise
    */
    Register<rtt_t, flow_id_t>(NUM_FLOWS) spin_delay_tracker_dup;
    RegisterAction<rtt_t, flow_id_t, bit<1>>(spin_delay_tracker_dup) current_time_smaller = { 
        void apply(inout rtt_t register_data, out bit<1> result) {
            if (meta.current_time < register_data){
                result =  1;
            } else{
                result = 0;
            }
            register_data = meta.current_time; 
        } 
    };

    // This register counts the number of individual measurements for the different flows
    Register<SPIN_MEASUREMENT_COUNTER, flow_id_t>(NUM_FLOWS) spin_measurement_counter;
    RegisterAction<SPIN_MEASUREMENT_COUNTER, flow_id_t, SPIN_MEASUREMENT_COUNTER>(spin_measurement_counter) track_this_measurement = { 
        void apply(inout SPIN_MEASUREMENT_COUNTER register_data, out SPIN_MEASUREMENT_COUNTER result) {
            register_data = register_data + 1;
            result = register_data;
        } 
    };



    /* 
    Protect against faulty measurement for the first RTT
    */
    Register<bit<1>, flow_id_t> (NUM_FLOWS) first_rtt_protection_reg;
    RegisterAction<bit<1>, flow_id_t, bit<1>>(first_rtt_protection_reg)
    set_measurement_state = {
        void apply(inout bit<1> register_data, out bit<1> result) {
            result = register_data;
            register_data = 1;
        }
    };



    /******************************************
    SPIN BIT PHASE CHANGE DETECTION (without Reordering Protection)
    ******************************************/
    // This register tracks the current spinbit phase of the different flows
    Register<bit<8>, flow_id_t>(NUM_FLOWS) spin_phase_tracker;
    RegisterAction<bit<8>, flow_id_t, bit<1>>(spin_phase_tracker) update_spin_phase = { 
        void apply(inout bit<8> register_data, out bit<1> result) {
            if ((bit<8>) hdr.quic_short.spin_bit != register_data){
                result = 1;
                register_data = (bit<8>) hdr.quic_short.spin_bit;
            } else{
                result = 0;
            }
        } 
    };




    /******************************************
    REORDERING PROTECTION (QBIT-STYLE)
    ******************************************/
    /*
    This register counts the number of new spin bit values during the threshold period. 
    It performs the phase transition if the threshold is reached (and returns 1 to indicate the transition).
    It returns 0 if there was no transition.
    */
    Register<struct_spin_threshold_counter, flow_id_t>(NUM_FLOWS) spinbit_threshold_phase_reg;    
    RegisterAction<struct_spin_threshold_counter, flow_id_t, bit<1>> (spinbit_threshold_phase_reg) spinbit_phase_threshold_action = { 
        void apply(inout struct_spin_threshold_counter register_data, out bit<1> result) {
            
            // Change in the spin bit
            if (register_data.phase[0:0] != hdr.quic_short.spin_bit){
                // Reordering threshold is reached -> do transition
                if (register_data.threshold_counter == (SPIN_REORDERING_THRESHOLD-1)){
                    register_data.phase = (bit<8>) hdr.quic_short.spin_bit;
                    register_data.threshold_counter = 0;
                    result = 1;
                } else{
                    // Increase threshold counter.
                    register_data.threshold_counter = register_data.threshold_counter + 1;
                    result = 0;
                } 
            } else {
                result = 0;
            }
        } 
    };

    /******************************************
    REORDERING PROTECTION (CONSECUTIVE PACKETS)
    ******************************************/
    /*
    This register counts the number of new spin bit values during the threshold period. 
    It performs the phase transition if the threshold is reached (and returns 1 to indicate the transition).
    It returns 0 if there was no transition.
    */
    Register<struct_spin_threshold_counter, flow_id_t>(NUM_FLOWS) spinbit_threshold_phase_reg_variant2;    
    RegisterAction<struct_spin_threshold_counter, flow_id_t, bit<1>> (spinbit_threshold_phase_reg_variant2) spinbit_phase_threshold_action_variant2 = { 
        void apply(inout struct_spin_threshold_counter register_data, out bit<1> result) {
            
            if (register_data.phase[0:0] != hdr.quic_short.spin_bit) {
                // Reordering threshold is reached -> do transition
                if (register_data.threshold_counter == (SPIN_REORDERING_THRESHOLD-1)){
                    register_data.phase = (bit<8>) hdr.quic_short.spin_bit;
                    register_data.threshold_counter = 0;
                    result = 1;
                } else{
                    // Increase threshold counter.  
                    register_data.threshold_counter = register_data.threshold_counter + 1;
                    result = 0;
                } 

            // Reset the threshold counting if there is a spin bit set to the old value in between
            } else {
                register_data.threshold_counter = 0;
                result = 0;
            }
        } 
    };


    // This register stores the latest RTT measurement of the different flows
    Register<rtt_t, flow_id_t>(NUM_FLOWS) spin_measurement_storage;
    RegisterAction<rtt_t, flow_id_t, rtt_t>(spin_measurement_storage) report_measurement = { 
        void apply(inout rtt_t register_data, out rtt_t result) {
            register_data = meta.current_rtt; 
        } 
    };


    /******************************************
    RING BUFFER
    ******************************************/
    /*
        This register stores the last `AVERAGE_BUFFER_SIZE` number of RTT measurements per flow.
        
        Its register action writes the current/new rtt measurement (`meta.current_rtt`) to the sample buffer and returns the previously stored value.
     */
    Register<rtt_t, bit<(FLOW_ID_BITS + AVERAGE_BUFFER_BITS)>> (NUM_FLOWS * AVERAGE_BUFFER_SIZE) rtt_ring_buffer;
    RegisterAction<rtt_t, bit<(FLOW_ID_BITS + AVERAGE_BUFFER_BITS)>, rtt_t>(rtt_ring_buffer)
    swap_rtt_entry = {
        void apply(inout rtt_t register_data, out rtt_t result) {
            result = register_data;
            register_data = meta.current_rtt;
        }
    };

    /* 
        This register is a duplicate of rtt_ring_buffer.
        Its register action returns whether the new measurement is smaller (1) or greater than/(equal) the old measurement (0)
    */
    Register<rtt_t, bit<(FLOW_ID_BITS + AVERAGE_BUFFER_BITS)>> (NUM_FLOWS * AVERAGE_BUFFER_SIZE) rtt_ring_buffer_dup;
    RegisterAction<rtt_t, bit<(FLOW_ID_BITS + AVERAGE_BUFFER_BITS)>, bit<1>>(rtt_ring_buffer_dup)
    old_rtt_is_larger = {
        void apply(inout rtt_t register_data, out bit<1> result) {
            
            if (register_data > meta.current_rtt){
                result = 1;
            } else{
                result = 0;
            }
            register_data = meta.current_rtt;
        }
    };

    /*
        This register holds the sum of the values stored in `rtt_ring_buffer`.
    
        The two register actions add/subtract the difference between the new and previously stored value.
    */
    Register<rtt_t, flow_id_t>(NUM_FLOWS) rtt_accumulator;
    RegisterAction<rtt_t, flow_id_t, rtt_t>(rtt_accumulator)
    add_rtt_diff = {
        void apply(inout rtt_t register_data, out rtt_t result) {
            register_data = register_data |+| meta.rtt_accumulator_change;
            result = register_data;
        }
    };
    RegisterAction<rtt_t, flow_id_t, rtt_t>(rtt_accumulator)
    sub_rtt_diff = {
        void apply(inout rtt_t register_data, out rtt_t result) {
            register_data = register_data |-| meta.rtt_accumulator_change;
            result = register_data;
        }
    };

    /*
        The buffer_index points to the position in the buffer which will be updated next.
        This value rotates through the buffer: 0 -> 1 -> 2 -> ... -> AVERAGE_BUFFER_SIZE -> 0 -> 1 -> ...
     
        Its register action moves the buffer index to the next position (and wraps around).
    */
    Register<bit<8>, flow_id_t>(NUM_FLOWS) buffer_index;
    RegisterAction<bit<AVERAGE_BUFFER_BITS>, flow_id_t, bit<AVERAGE_BUFFER_BITS>>(buffer_index)
    inc_index = {
        void apply(inout bit<AVERAGE_BUFFER_BITS> register_data, out bit<AVERAGE_BUFFER_BITS> result) {
            result = register_data;
            if(register_data == (AVERAGE_BUFFER_SIZE - 1)){
                register_data = 0;
            }else{
                register_data = register_data + 1;
            }
        }
    };


    /******************************************
    RTT Classification
    ******************************************/

    // Register holding the RTT class "hits" for each flow
    Register<bit<RTT_CLASS_COUNTER_BITS>, bit<(FLOW_ID_BITS + RTT_CLASS_BITS)>>(NUM_FLOWS*NUM_RTT_CLASSES) rtt_class_counter;

    RegisterAction<bit<RTT_CLASS_COUNTER_BITS>, bit<(FLOW_ID_BITS + RTT_CLASS_BITS)>, bit<RTT_CLASS_COUNTER_BITS>>(rtt_class_counter)
    inc_rtt_class = {
        void apply(inout bit<RTT_CLASS_COUNTER_BITS> register_data, out bit<RTT_CLASS_COUNTER_BITS> result) {
            register_data = register_data + 1;
            result = register_data;
        }
    };
    
    action set_rtt_class(bit<RTT_CLASS_BITS>  class){
        meta.rtt_class_temp = class;
    }

    table rtt_class_table {
        key = {
            meta.rtt_accumulator_value : range;
            meta.current_rtt : range;
        }

        actions = {
            set_rtt_class;
            NoAction;
        } 
        const default_action = set_rtt_class(2);
        size = RTT_CLASS_TABLE_SIZE; 
    }

    /***************************
    REORDER PROTECTION SELECTOR
    ****************************/

    action select_spinbit(){
        meta.reorder_selector = 0;
    }
    action select_qbit_reorder(){
        meta.reorder_selector = 1;
    }
    action select_consec_reorder(){
        meta.reorder_selector = 2;
    }

    table reorder_protection_selector {
        key = {
            hdr.quic_short.quic_bit : exact;
        }
        actions = {
            select_spinbit;select_qbit_reorder;select_consec_reorder;
        }

        default_action = select_spinbit();
        size = 2; 
    }

    action mirror_to_controlplane() {
        ig_dprsr_md.mirror_type    = DEPARSER_MIRROR;
        meta.mirror_session = CONTROLPLANE_MIRROR;
        meta.mirror_header_type = HEADER_TYPE_MIRROR;
    }

    Hash<bit<16>>(HashAlgorithm_t.IDENTITY) bit_hash_16;
    Hash<bit<18>>(HashAlgorithm_t.IDENTITY) bit_hash_18;
    apply {

        // Extract 16 bits from the timestamp
        meta.current_time = bit_hash_16.get(ig_intr_md.ingress_mac_tstamp[35:20]);

        // Select reorder protection scheme
        reorder_protection_selector.apply();

        // Prepare ringbuffer and RTT classification operations
        meta.swap_index[AVERAGE_BUFFER_BITS + FLOW_ID_BITS - 1:AVERAGE_BUFFER_BITS] = bit_hash_18.get(meta.flow_id[FLOW_ID_BITS - 2:0]);
        meta.rtt_class_index[RTT_CLASS_BITS + FLOW_ID_BITS - 1:RTT_CLASS_BITS] = meta.flow_id;

        // Determine whether a spin bit phase change has happened
        if (meta.reorder_selector == 1) {
            meta.spinbit_new_phase = spinbit_phase_threshold_action.execute(meta.flow_id);
        } else if (meta.reorder_selector == 2) {
            meta.spinbit_new_phase = spinbit_phase_threshold_action_variant2.execute(meta.flow_id);
        } else {
            meta.spinbit_new_phase = update_spin_phase.execute(meta.flow_id);
        }

        // Spin bit phase change has happened
        if (meta.spinbit_new_phase == 1){ 

            // Compute current RTT
            meta.current_rtt = update_timestamp.execute(meta.flow_id);

            // If there was a wraparound, properly account for that
            meta.current_time_smaller = current_time_smaller.execute(meta.flow_id);
            if (meta.current_time_smaller == 1){
                meta.current_rtt = 0xFFFF - meta.current_rtt;
            }

            // Used to protect against faulty measurements in the first RTT
            bit<1> tmp = set_measurement_state.execute(meta.flow_id);

            if (tmp == 1){

                // Count this measurement
                meta.measurement_count = track_this_measurement.execute(meta.flow_id);
                // Store measured RTT
                report_measurement.execute(meta.flow_id);
            
                /*****************
                    Ring Buffer
                *****************/
                // Find the correct index for manipulation
                meta.swap_index[AVERAGE_BUFFER_BITS-1:0] = inc_index.execute(meta.flow_id); 
                // Update the corresponding entry in the ring buffer
                meta.removed_rtt = swap_rtt_entry.execute(meta.swap_index);
                meta.rtt_accumulator_change_negative = old_rtt_is_larger.execute(meta.swap_index);

                // Compute difference between the removed and the newly added RTT
                if (meta.rtt_accumulator_change_negative == 1){
                    meta.rtt_accumulator_change = meta.removed_rtt - meta.current_rtt;
                    meta.rtt_accumulator_value = sub_rtt_diff.execute(meta.flow_id);
                } else {
                    meta.rtt_accumulator_change = meta.current_rtt - meta.removed_rtt;
                    meta.rtt_accumulator_value = add_rtt_diff.execute(meta.flow_id);
                }
                
                /*****************
                    RTT class classification
                *****************/
                // Compute class of current RTT according to accumulator average + increment counter
                rtt_class_table.apply();

                // Report everything via a mirrored packet
                meta.rtt_class_index[(RTT_CLASS_BITS-1):0] = meta.rtt_class_temp;
                meta.class_counter = inc_rtt_class.execute(meta.rtt_class_index);
                meta.class_number = (bit<8>) meta.rtt_class_temp;

                mirror_to_controlplane();
            }
        } 
    }
}