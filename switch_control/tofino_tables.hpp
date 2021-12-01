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

struct key_list_entry {
  std::unique_ptr<bfrt::BfRtTableKey> key;
};

struct action_def {
  bf_rt_id_t id;
  std::unique_ptr<bfrt::BfRtTableData> data_ref;
  std::map<std::string, bf_rt_id_t> data_fields;

  action_def(std::map<std::string, bf_rt_id_t> fields)
          : data_fields(fields)
  {}

  action_def() {};
};

struct table_def {
  const bfrt::BfRtTable* table;

  std::unique_ptr<bfrt::BfRtTableKey> key_ref;

  std::map<std::string, bf_rt_id_t> keys;
  std::map<std::string, action_def> actions;
};

class TofinoTables {
 private:
  Switchd* switchd;
  std::map<std::string, table_def> tables;

 public:
  TofinoTables(Switchd* switchd);
  void initializeTables();
  void enableQBitReorderProtection();
  void enableConsecReorderProtection();
  void RTTClassTableSetEntry(uint16_t accumulator_min, uint16_t accumulator_max, uint16_t rtt_min, uint16_t rtt_max, uint8_t rtt_class);
};