/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	  Author: Ike Kunze
	  E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

#pragma once
#include <loguru.hpp>

#include "switchd.hpp"

class TofinoRegister {
 private:
  Switchd* switchd;
  const BfRtTable* table;

  bf_rt_id_t reg_index_key_id;
  bf_rt_id_t data_id;

 public:
  TofinoRegister(std::string register_name, Switchd* switchd);
  uint64_t read(uint64_t index, uint64_t pipe_id);
  void write(uint64_t index, uint64_t value);
};