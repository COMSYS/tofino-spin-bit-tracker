#!/usr/bin/env python2

max_mirror_length = 12
controlplane_port = 192

print("Setup mirroring to control plane port ", 192)
mirror.session_create(mirror.MirrorSessionInfo_t(
    mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
    direction=mirror.Direction_e.PD_DIR_BOTH,
    mir_id=1,
    egr_port=controlplane_port,
    egr_port_v=True,
    max_pkt_len=max_mirror_length))