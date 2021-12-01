/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	Author: Ike Kunze
	E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

typedef bit<48> MAC_ADDR_t;
typedef bit<32> IPV4_ADDR_t;
typedef bit<128> IPV6_ADDR_t;

typedef bit<16> ETHER_TYPE_t;
const ETHER_TYPE_t ETHERTYPE_IPV4 = 0x0800;
const ETHER_TYPE_t ETHERTYPE_IPV6 = 0x86dd;
const ETHER_TYPE_t ETHERTYPE_ARP = 0x0806;

typedef bit<8> IP_PROTOCOL_t;
const IP_PROTOCOL_t IP_PROTOCOL_TCP = 6;
const IP_PROTOCOL_t IP_PROTOCOL_UDP = 17;


header ethernet_h {
    MAC_ADDR_t   dst_addr;
    MAC_ADDR_t   src_addr;
    ETHER_TYPE_t   ether_type;
}

header arp_h {
    bit<16> hw_type;
    bit<16> proto_type;
    bit<8> hw_size;
    bit<8> proto_size;
    bit<16> opp_code;
    bit<48> src_mac;
    bit<32> src_ipv4;
    bit<48> dst_mac;
    bit<32> dst_ipv4;
}

header ipv4_h {
    bit<4>   version;
    bit<4>   ihl;
    bit<8>   diffserv;
    bit<16>  total_len;
    bit<16>  identification;
    bit<3>   flags;
    bit<13>  frag_offset;
    bit<8>   ttl;
    bit<8>   protocol;
    bit<16>  hdr_checksum;
    IPV4_ADDR_t src_addr;
    IPV4_ADDR_t dst_addr;
}

header ipv6_h {
    bit<4>   version;
    bit<8>   tclass;
    bit<20>  flow;
    bit<16>  len;
    bit<8>   next_hdr;
    bit<8>   ttl;
    IPV6_ADDR_t src_addr;
    IPV6_ADDR_t dst_addr;
}

header udp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> length;
    bit<16> checksum;
}

// Short header structure of a modified QUIC implementation (https://github.com/COMSYS/aioquic) 
header quic_short_h {
    bit<1> header_form;
    bit<1> quic_bit;
    bit<1> spin_bit;
    bit<1> vec_high;
    bit<1> vec_low;
    bit<1> delay_bit_paper;
    bit<1> delay_bit_draft;
    @padding bit<1> _pad1;
    bit<1> q_bit;
    bit<1> r_bit;
    bit<1> l_bit;
    bit<1> t_bit;
    @padding bit<1> _pad2;
    bit<1> key_phase;
    bit<2> packet_number_length;
}

header quic_long_h {
    bit<1> header_form;
    bit<1> quic_bit;
    @padding bit<6> _pad3;
}