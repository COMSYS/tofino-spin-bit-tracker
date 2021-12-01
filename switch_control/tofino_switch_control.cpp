/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	  Author: Ike Kunze
	  E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

#include "tofino_switch_control.hpp"
#include <iostream>

TofinoSwitchControl::TofinoSwitchControl(std::string file_path, bool spinbit_enabled, int spinbit_reorderingprotection) {

  this->file_path = file_path;
	this->spinbit_enabled = spinbit_enabled;
  this->spinbit_reorderingprotection = spinbit_reorderingprotection;

  switchd = new Switchd("spintracker");
  switchd->start();
  LOG_F(INFO, "BFRT Switchd initialization finished");
}

void TofinoSwitchControl::initializeDataplaneInterfaces() {
  tables = new TofinoTables(switchd);

  if (this->spinbit_enabled){
    spin_measurement_register = new TofinoRegister("Ingress.spinbit.spin_measurement_storage", switchd);
    spin_measurement_counter_register = new TofinoRegister("Ingress.spinbit.spin_measurement_counter", switchd);
    spin_ring_buffer_register = new TofinoRegister("Ingress.spinbit.rtt_accumulator", switchd);
    spin_raw_timestamp_register = new TofinoRegister("Ingress.spinbit.spin_delay_tracker", switchd);
    spin_rtt_class_counter_register = new TofinoRegister("Ingress.spinbit.rtt_class_counter", switchd);
  }

  LOG_F(INFO, "Initialized dataplane interfaces");
  sessionCompleteOperations();
}

void TofinoSwitchControl::setupPort(uint64_t num, bf_port_speed_t speed) {
  bf_status_t status;

  bf_pal_front_port_handle_t port_handle;
  status = bf_pm_port_dev_port_to_front_panel_port_get(
      switchd->device_target.dev_id, num, &port_handle);
  CHECK_F(status == BF_SUCCESS, "Failed to acquire port handle for port num %d",
          num);

  status = bf_pm_port_add(switchd->device_target.dev_id, &port_handle, speed,
                          BF_FEC_TYP_NONE);
  CHECK_F(status == BF_SUCCESS, "Failed to add port %d", num);

  status = bf_pm_port_enable(switchd->device_target.dev_id, &port_handle);
  CHECK_F(status == BF_SUCCESS, "Failed to enable port %d", num);
}

void TofinoSwitchControl::setupDataplane() {
  bf_status_t bf_status;
  bf_status = bf_tm_port_cpuport_set(switchd->device_target.dev_id, 192);
  CHECK_F(bf_status == BF_SUCCESS, "Failed to configure CPU port");
  LOG_F(INFO, "Activated CPU port, port number %d", 192);
  sessionCompleteOperations();
}


void TofinoSwitchControl::sessionCompleteOperations() {
  bf_status_t bf_status;
  bf_status = switchd->session->sessionCompleteOperations();
  assert(bf_status == BF_SUCCESS);
}

void TofinoSwitchControl::setSpinReorderProtection(){

  if (this->spinbit_enabled){
    if (this->spinbit_reorderingprotection == 1){
      LOG_F(INFO, "Activated Spin QBIT Reorder Protection.");
      this->tables->enableQBitReorderProtection();
    } else if(this->spinbit_reorderingprotection == 2){
      LOG_F(INFO, "Activated Spin Consec Reorder Protection.");
      this->tables->enableConsecReorderProtection();
    } else{
      LOG_F(INFO, "No Reordering Protection.");
    }
  }
}

  void TofinoSwitchControl::RTTClassTableSetEntry(uint16_t accumulator_min, uint16_t accumulator_max, uint16_t rtt_min, uint16_t rtt_max, uint8_t rtt_class){
    this->tables->RTTClassTableSetEntry(accumulator_min, accumulator_max, rtt_min, rtt_max, rtt_class);
  }
