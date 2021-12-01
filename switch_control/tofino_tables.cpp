/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	  Author: Ike Kunze
	  E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

#include "tofino_tables.hpp"
#include <iostream>

TofinoTables::TofinoTables(Switchd* switchd) {
  this->switchd = switchd;
  initializeTables();
}

void TofinoTables::initializeTables() {

  tables["Ingress.spinbit.rtt_class_table"] = table_def{};
  tables["Ingress.spinbit.rtt_class_table"].keys["meta.rtt_accumulator_value"] = 0;
  tables["Ingress.spinbit.rtt_class_table"].keys["meta.current_rtt"] = 0;
  tables["Ingress.spinbit.rtt_class_table"].actions["Ingress.spinbit.set_rtt_class"] = action_def({{"class", 0},});
  tables["Ingress.spinbit.rtt_class_table"].actions["NoAction"] = action_def();


  tables["Ingress.spinbit.reorder_protection_selector"] = table_def{};
  tables["Ingress.spinbit.reorder_protection_selector"].keys["hdr.quic_short.quic_bit"] = 0;
  tables["Ingress.spinbit.reorder_protection_selector"].actions["Ingress.spinbit.select_spinbit"] = action_def();
  tables["Ingress.spinbit.reorder_protection_selector"].actions["Ingress.spinbit.select_qbit_reorder"] = action_def();
  tables["Ingress.spinbit.reorder_protection_selector"].actions["Ingress.spinbit.select_consec_reorder"] = action_def();


  for (auto& table : tables) {
    auto bf_status = switchd->bfrtInfo->bfrtTableFromNameGet(table.first, &table.second.table);
    assert(bf_status == BF_SUCCESS);

    bf_status = table.second.table->keyAllocate(&table.second.key_ref);
    assert(bf_status == BF_SUCCESS);

    for (auto& key : table.second.keys) {
      bf_status = table.second.table->keyFieldIdGet(key.first, &key.second);
      assert(bf_status == BF_SUCCESS);
    }

    for (auto& action : table.second.actions) {
      bf_status = table.second.table->actionIdGet(action.first, &action.second.id);
      assert(bf_status == BF_SUCCESS);

      bf_status = table.second.table->dataAllocate(action.second.id, &action.second.data_ref);
      assert(bf_status == BF_SUCCESS);

      for (auto& field : action.second.data_fields) {
        bf_status = table.second.table->dataFieldIdGet(field.first, action.second.id, &field.second);
        assert(bf_status == BF_SUCCESS);
      }
    }
  }
}


void TofinoTables::enableQBitReorderProtection(){
  auto& table_ref = tables["Ingress.spinbit.reorder_protection_selector"];

  key_list_entry result;

  auto bf_status = table_ref.table->keyReset(table_ref.key_ref.get());
  table_ref.table->keyAllocate(&result.key);
  auto& action_ref = table_ref.actions["Ingress.spinbit.select_qbit_reorder"];

  bf_status = table_ref.table->keyReset(table_ref.key_ref.get());
  assert(bf_status == BF_SUCCESS);

  table_ref.table->keyAllocate(&result.key);

  bf_status = result.key->setValue(table_ref.keys["hdr.quic_short.quic_bit"], 1);
  assert(bf_status == BF_SUCCESS);

  bf_status = table_ref.table->dataReset(action_ref.id, action_ref.data_ref.get());
  assert(bf_status == BF_SUCCESS);

  bf_status = table_ref.table->tableEntryAdd(*switchd->session, switchd->device_target, *result.key, *action_ref.data_ref);
  assert(bf_status == BF_SUCCESS);
}

void TofinoTables::enableConsecReorderProtection(){
  auto& table_ref = tables["Ingress.spinbit.reorder_protection_selector"];

  key_list_entry result;

  auto bf_status = table_ref.table->keyReset(table_ref.key_ref.get());
  table_ref.table->keyAllocate(&result.key);
  auto& action_ref = table_ref.actions["Ingress.spinbit.select_consec_reorder"];

  bf_status = table_ref.table->keyReset(table_ref.key_ref.get());
  assert(bf_status == BF_SUCCESS);

  table_ref.table->keyAllocate(&result.key);

  bf_status = result.key->setValue(table_ref.keys["hdr.quic_short.quic_bit"], 1);
  assert(bf_status == BF_SUCCESS);

  bf_status = table_ref.table->dataReset(action_ref.id, action_ref.data_ref.get());
  assert(bf_status == BF_SUCCESS);

  bf_status = table_ref.table->tableEntryAdd(*switchd->session, switchd->device_target, *result.key, *action_ref.data_ref);
  assert(bf_status == BF_SUCCESS);
}


void TofinoTables::RTTClassTableSetEntry(uint16_t accumulator_min, uint16_t accumulator_max, uint16_t rtt_min, uint16_t rtt_max, uint8_t rtt_class){

  auto& table_ref = tables["Ingress.spinbit.rtt_class_table"];
  key_list_entry result;

  auto bf_status = table_ref.table->keyReset(table_ref.key_ref.get());
  assert(bf_status == BF_SUCCESS);

  table_ref.table->keyAllocate(&result.key);
  bf_status = result.key->setValueRange(table_ref.keys["meta.rtt_accumulator_value"], accumulator_min, accumulator_max);
  assert(bf_status == BF_SUCCESS);

  bf_status = result.key->setValueRange(table_ref.keys["meta.current_rtt"], rtt_min, rtt_max);
  assert(bf_status == BF_SUCCESS);

  auto& action_ref = table_ref.actions["Ingress.spinbit.set_rtt_class"];
  bf_status = table_ref.table->dataReset(action_ref.id, action_ref.data_ref.get());
  assert(bf_status == BF_SUCCESS);

  bf_status = action_ref.data_ref->setValue(action_ref.data_fields["class"], (uint64_t) rtt_class);
  assert(bf_status == BF_SUCCESS);

  bf_status = table_ref.table->tableEntryAdd(*switchd->session, switchd->device_target, *result.key, *action_ref.data_ref);
  assert(bf_status == BF_SUCCESS);
}