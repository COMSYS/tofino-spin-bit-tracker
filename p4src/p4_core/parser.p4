/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	Author: Ike Kunze
	E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

parser TofinoIngressParser(
        packet_in pkt,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        transition select(ig_intr_md.resubmit_flag) {
            1 : parse_resubmit;
            0 : parse_port_metadata;
        }
    }

    state parse_resubmit {
        transition reject;
    }

    state parse_port_metadata {
        pkt.advance(PORT_METADATA_SIZE);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Actual Ingress parser
// ---------------------------------------------------------------------------
parser SwitchIngressParser(
        packet_in pkt,
        out ingress_headers_t hdr,
        out ingress_metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    TofinoIngressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, ig_intr_md);
        ig_md.spinbit_new_phase = 0;
        ig_md.flow_registered = 0;
        ig_md.current_time = 0;
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
            ETHERTYPE_IPV6 : parse_ipv6;
            ETHERTYPE_ARP: parse_arp;
            default : accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROTOCOL_TCP : parse_tcp;
            IP_PROTOCOL_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_hdr) {
            IP_PROTOCOL_TCP : parse_tcp;
            IP_PROTOCOL_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        bit<2> quic_bits = pkt.lookahead<bit<2>>();
        transition select(quic_bits) {
            2w1 : parse_quic_shortheader;
            2w3 : parse_quic_longheader;
            default: accept;
        }
    }

    state parse_tcp {
        transition accept;
    }

    state parse_quic_shortheader {
        pkt.extract(hdr.quic_short);
        transition accept;
    }

    state parse_quic_longheader {
        pkt.extract(hdr.quic_long);
        transition accept;
    }

}

// ---------------------------------------------------------------------------
// Ingress Deparser
// ---------------------------------------------------------------------------
control SwitchIngressDeparser(
        packet_out pkt,
        inout ingress_headers_t hdr,
        in ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

    Mirror() mirror;


    apply {
        if (ig_dprsr_md.mirror_type == DEPARSER_MIRROR) {
            mirror.emit<mirror_header_h>(ig_md.mirror_session, {
                ig_md.mirror_header_type,
                ig_md.flow_id,
                ig_md.measurement_count,
                ig_md.current_time,
                ig_md.current_rtt,
                ig_md.rtt_accumulator_value,
                ig_md.class_counter,
                ig_md.class_number
            });
        }
        pkt.emit<ingress_headers_t>(hdr);
    } 
}