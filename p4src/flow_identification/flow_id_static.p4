/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	Author: Ike Kunze
	E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

control Flow_ID_Static(
    inout ingress_headers_t                       hdr,
    inout ingress_metadata_t                      meta,
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md)
{

    action track_flow(bit<FLOW_ID_BITS> flow_id){
        meta.flow_id = flow_id;
        meta.flow_registered = 1;
    }

    table flow_id_v4 {

        key = {
            hdr.ipv4.src_addr : exact;
            hdr.ipv4.dst_addr : exact;
            hdr.udp.src_port : exact;
            hdr.udp.dst_port : exact;
        }

        actions = {
            track_flow;
            NoAction;
        }

        size = NUM_FLOWS;
        /*
        You can statically define the flows to track here or you can add them dynamically
        const entries = {
            (0x0a000016, 0x0a000020, 1234, 4321) : track_flow(0);
        }
        */
        const default_action = NoAction;
    }

    apply {
        flow_id_v4.apply();
    }
}
