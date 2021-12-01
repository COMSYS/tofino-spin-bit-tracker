/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	  Author: Ike Kunze
	  E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

#pragma once
#include <bf_switchd/bf_switchd.h>
#include <loguru.hpp>

#include <pipe_mgr/pipe_mgr_mirror_intf.h>


extern "C" {
#include <traffic_mgr/traffic_mgr.h>
#include <bf_pm/bf_pm_intf.h>
}

#include "switchd.hpp"
#include "tofino_register.hpp"
#include "tofino_tables.hpp"
#include <pthread.h>

class TofinoSwitchControl {
 public:
  Switchd* switchd;
  pthread_t readDataplane_thread;

  // Dataplane Constructs
  TofinoRegister* spin_measurement_register;
  TofinoRegister* spin_measurement_counter_register;
  TofinoRegister* spin_ring_buffer_register;
  TofinoRegister* spin_raw_timestamp_register;
  TofinoRegister* spin_rtt_class_counter_register;
  TofinoTables* tables;

  // Attributes
  std::string file_path;
	bool spinbit_enabled;
  int spinbit_reorderingprotection;

  TofinoSwitchControl(std::string file_path, bool spinbit_enabled, int spinbit_reorderingprotection);

  void initializeTables();
  void initializeDataplaneInterfaces();
  void setupDataplane();
  void setupPort(uint64_t num, bf_port_speed_t speed);
  void sessionCompleteOperations();

  void setSpinReorderProtection();
  void RTTClassTableSetEntry(uint16_t accumulator_min, uint16_t accumulator_max, uint16_t rtt_min, uint16_t rtt_max, uint8_t rtt_class);

};
