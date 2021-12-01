/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	Author: Ike Kunze
	E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

#include <core.p4>
#include <tna.p4>

typedef bit<16> rtt_t;

// Mirror related parameters
const MirrorId_t CONTROLPLANE_MIRROR  = 1;
const bit<3> DEPARSER_MIRROR = 0x3;
typedef bit<6> header_type_t;
const header_type_t HEADER_TYPE_MIRROR = 0b101010;


/*
Program parameters:

## General Parameters
- FLOW_ID_BITS: #bits used for flow identifiers
- NUM_FLOWS: #flows that can be tracked at the same time
- TIMESTAMP_SIZE: #bits used for timestamps

## Additional Measurement Counter
- SPIN_MEASUREMENT_COUNTER: Size of a counter in bit that counts the number of individual measurements per flow


## Average Buffer
- AVERAGE_BUFFER_BITS: #bits indexing the average buffer
- AVERAGE_BUFFER_SIZE: #values stored in the average buffer

## RTT Classification
- RTT_CLASS_TABLE_SIZE: #entries in the RTT classification table
- NUM_RTT_CLASSES: #RTT-classes 
- RTT_CLASS_BITS: #bits indexing the RTT classes
- RTT_CLASS_COUNTER_BITS: #bits used for the class counters 

## Reorder Protection
- SPIN_REORDERING_THRESHOLD: reorder protection threshold

*/

// General Parameters
#define FLOW_ID_BITS 18
typedef bit<FLOW_ID_BITS> flow_id_t;
#define NUM_FLOWS (10)
#define TIMESTAMP_SIZE bit<16>

// Additional Measurement Counter
#define SPIN_MEASUREMENT_COUNTER bit<8>

// Average Buffer
#define AVERAGE_BUFFER_BITS 3
#define AVERAGE_BUFFER_SIZE 4

// RTT Classification
#define RTT_CLASS_TABLE_SIZE 1000
#define NUM_RTT_CLASSES 8
#define RTT_CLASS_BITS 3
#define RTT_CLASS_COUNTER_BITS 8

// Reorder Protection
#define SPIN_REORDERING_THRESHOLD 3



/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

#include "p4_core/headers.p4"

struct ingress_headers_t {
    ethernet_h      ethernet;
    arp_h           arp;
    ipv4_h          ipv4;
    ipv6_h          ipv6;
    udp_h           udp;
    quic_short_h    quic_short;
    quic_long_h     quic_long;
}


    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct ingress_metadata_t {

    // Mirroring related variables
    MirrorId_t    mirror_session;
    header_type_t mirror_header_type;

    // Flow identification
    bit<FLOW_ID_BITS> flow_id; 

    // Whether the flow is already registered, i.e., whether it is to be used for measurements
    bit<1> flow_registered;

    // Which reorder protection to choose: 0 (Spin Bit), 1 (protection v1), 2 (protection v2)    
    bit<2> reorder_selector;

    // Whether there was a phase transition
    bit<1> spinbit_new_phase;

    // Extracted timestamp
    rtt_t current_time;
    // Computed RTT
    rtt_t current_rtt;

    // Protection against timestamp overflow
    // Indicates whether current_time is smaller than the previous value
    bit<1> current_time_smaller;

    // Count the number of measurements
    bit<8> measurement_count;


    /*
     Average Buffer Related Variables
    */
    // Current read/write entry of the ring buffer
    bit<(FLOW_ID_BITS + AVERAGE_BUFFER_BITS)> swap_index;
    // Value removed from the ring buffer
    rtt_t removed_rtt;
    // RTT Accumulator Update
    // 1. Check whether accumulator value has increased or decreased
    bit<1> rtt_accumulator_change_negative;
    // 2. Correctly compute how the accumulator has changed
    rtt_t rtt_accumulator_change;
    // 3. Apply the changes
    rtt_t rtt_accumulator_value;
    
    /*
    RTT Classification Related Variables
    */
    // RTT class
    bit<RTT_CLASS_BITS> rtt_class_temp;
    // Actual identifier, also including the prepended flow ID
    bit<(FLOW_ID_BITS + RTT_CLASS_BITS)> rtt_class_index;
    // Current value of the respective counter
    bit<8> class_counter;
    // ID of the current class
    bit<8> class_number;
}


// Mirror header that is prepended for measurement report packets
header mirror_header_h {
    header_type_t type;
    /*
    Reported values are the corresponding variables from the intrinsic metadata
    */
    bit<FLOW_ID_BITS> flow_id;
    bit<8> measurement_count;
    bit<16> current_time;
    rtt_t current_rtt;
    rtt_t rtt_accumulator_value;
    bit<8> class_counter;
    bit<8> class_id;
}




    /***********************  H E A D E R S  ************************/

struct egress_headers_t {
    mirror_header_h mirror_header;
}

    /******  G L O B A L   E G R E S S   M E T A D A T A  *********/


struct egress_metadata_t {
}


/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  P A R S E R  **************************/

#include "p4_core/parser.p4"
    // See parser.p4

    /***************** M A T C H - A C T I O N  *********************/


#include "flow_identification/flow_id_static.p4"
#include "observer_logic/Spin_bit.p4"

control Ingress(
    inout ingress_headers_t                       hdr,
    inout ingress_metadata_t                      meta,
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md)
{

    action forward (PortId_t port){
        ig_tm_md.ucast_egress_port = port;
    }

    table static_ipv4_forwarding {
        key = { 
            hdr.ipv4.dst_addr: exact; 
        }
        actions = { 
            forward; 
            @defaultonly NoAction; }
        size = 128;
        default_action = NoAction;
    }

    table static_ethernet_forwarding {
        key = {
            hdr.ethernet.src_addr: exact;
            hdr.ethernet.dst_addr: exact;
        }
        actions = {
            NoAction;
            forward;
        }
        size = 128;
        default_action = NoAction;
    }

    SpinBit() spinbit;
    Flow_ID_Static() flow_identification;


    apply {

        if (hdr.arp.isValid()){
            static_ethernet_forwarding.apply();
        } else{
            static_ipv4_forwarding.apply();
        }

        flow_identification.apply(hdr, meta, ig_intr_md, ig_tm_md);
        if (meta.flow_registered == 1 && hdr.quic_short.isValid()){
            spinbit.apply(hdr, meta, ig_intr_md, ig_tm_md, ig_dprsr_md);
        }

    }
}

    /*********************  D E P A R S E R  ************************/
    // see parser.p4



/*************************************************************************
 ***************  E G R E S S   P R O C E S S I N G   ********************
 *************************************************************************/


    /***********************  P A R S E R  **************************/
    parser TofinoEgressParser(
            packet_in pkt,
            out egress_intrinsic_metadata_t eg_intr_md) {
        
        state start {
            pkt.extract(eg_intr_md);
            transition accept;
        }
    }

    parser SwitchEgressParser(
            packet_in pkt,
            out egress_headers_t hdr,
            out egress_metadata_t eg_md,
            out egress_intrinsic_metadata_t eg_intr_md) {

        TofinoEgressParser() tofino_parser;

        state start {
            tofino_parser.apply(pkt, eg_intr_md);
            transition accept;
        }

        state egress_mirror_parser {
            header_type_t type = pkt.lookahead<header_type_t>();

            transition select(type) {
                (HEADER_TYPE_MIRROR): parse_mirror;
                default                 : accept;
            }
        }

        state parse_mirror {
            pkt.extract(hdr.mirror_header);
            transition consume_payload;
        }

        state consume_payload {
            pkt.advance(32768);
            transition accept;
        }
    }

/*************************************************************************
 ***************  E G R E S S   P R O C E S S I N G   ********************
 *************************************************************************/
 
    
    /***************** M A T C H - A C T I O N  *********************/

control Egress(
    inout egress_headers_t                          hdr,
    inout egress_metadata_t                         meta,
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md)
{
    apply {
    }
} 

    /*********************  D E P A R S E R  ************************/
    control SwitchEgressDeparser(
            packet_out pkt,
            inout egress_headers_t hdr,
            in egress_metadata_t eg_md,
            in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {

        apply {
            pkt.emit(hdr);
        }
    }


/************ F I N A L   P A C K A G E ******************************/
Pipeline(
    SwitchIngressParser(),
    Ingress(),
    SwitchIngressDeparser(),
    SwitchEgressParser(),
    Egress(),
    SwitchEgressDeparser()
) pipe;

Switch(pipe) main;
