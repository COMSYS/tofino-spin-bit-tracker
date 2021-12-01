# Tracking the QUIC Spin Bit on Tofino

This repository contains the data plane and control plane implementation for our QUIC Spin Bit Tracker in P4<sub>16</sub>.
Note: The code has been tested with SDE-9.7.0.

## Publication

* Ike Kunze, Constantin Sander, Klaus Wehrle and Jan Rüth: *Tracking the QUIC Spin Bit on Tofino*. In Proceedings of the 3rd Workshop on the Evolution, Performance and Interoperability of QUIC (EPIQ '21), 2021.

If you use any portion of our work, please consider citing our publication.

```
@inproceedings{2021-kunze-spin-tracker,
	author = {Kunze, Ike and Sander, Constantin and Wehrle, Klaus and R{\"u}th, Jan},
	title = {{Tracking the QUIC Spin Bit on Tofino}},
	booktitle = {Proceedings of the 3rd Workshop on the Evolution, Performance and Interoperability of QUIC (EPIQ '21)},
	year = {2021},
	month = {12},
	doi = {10.1145/3488660.3493804}
}
```


## Content


### P4_16 Implementation

The P4_16 source code for the spin bit tracker is located in ``p4src``.
The code is divided into different components.

File | Purpose
--- | ---
``spintracker.p4`` | Main program file: contains overall program structure, program parameters, and specifies the metadata structure
``flow_identification/flow_id_static.p4`` | Logic for identifying a flow. Five-tuple variant with statically defined flow ids.
``p4_core/headers.p4`` | Header definitions
``p4_core/parser.p4`` | Ingress parser and deparser
``observer_logic/Spin_bit.p4`` | Spin bit tracking logic


### Controlplane Implementation

The controlplane implementation is located in ``switch_control``.
It can be built using CMAKE.
It expects loguru to be installed in /opt/loguru

``switch_control/run_switch_control.sh --spin_enabled --file {FILEPATH} --spin_reorderprotection {VAL} --pipe_id {ID} --readout_sleep_ms {VAL} --configured_rtt {VAL} --min_latency {VAL} --max_latency {VAL}`` wraps starting the control plane with several commandline parameters.
Essentially, it just passes the parameters through to the actual control plane program.
- spin_enabled: If set, spin bit measurements are enabled.
- file FILEPATH: Configure the outputfile path of the controlplane file (REQUIRED)
- spin_reorderprotection VAL: Which reorderprotection scheme to use (default: 0 -> no protection)
- pipe_id ID: On which pipe is the program deployed?
- readout_sleep_ms VAL: Interval for reading out the registers
- configured_rtt VAL: Mean RTT targeted by the program
- min_latency VAL: Configure RTT classes manually 
- max_latency VAL: Configure RTT classes manually

        
``run_pd_rpc/setup_mirror_sessions.py`` is a helper script to setup the mirror session.


## License
This project is free software: you can redistribute it and/or modify it under the terms of the MIT License.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the MIT License for more details.