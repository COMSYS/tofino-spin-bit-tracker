/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	  Author: Ike Kunze
	  E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

#include "tofino_register.hpp"

#include <vector>

TofinoRegister::TofinoRegister(std::string register_name, Switchd* switchd) {
  this->switchd = switchd;

  char data_field[128];
  snprintf(data_field, 128, "%s.f1", register_name.c_str());

  bf_status_t bf_status;

  bf_status =
      switchd->bfrtInfo->bfrtTableFromNameGet(register_name.c_str(), &table);
  assert(bf_status == BF_SUCCESS);

  bf_status = table->keyFieldIdGet("$REGISTER_INDEX", &reg_index_key_id);
  assert(bf_status == BF_SUCCESS);

  bf_status = table->dataFieldIdGet(data_field, &data_id);
  assert(bf_status == BF_SUCCESS);
}

uint64_t TofinoRegister::read(uint64_t key, uint64_t pipe_id) {
  bf_status_t bf_status;

  auto flag = bfrt::BfRtTable::BfRtTableGetFlag::GET_FROM_HW;

  std::unique_ptr<BfRtTableKey> table_key;
  std::unique_ptr<BfRtTableData> table_data;

  bf_status = table->keyAllocate(&table_key);
  assert(bf_status == BF_SUCCESS);

  bf_status = table->dataAllocate(&table_data);
  assert(bf_status == BF_SUCCESS);

  bf_status = table_key->setValue(reg_index_key_id, key);
  assert(bf_status == BF_SUCCESS);

  bf_status = table->tableEntryGet(*switchd->session, switchd->device_target,
                                   *table_key.get(), flag, table_data.get());
  assert(bf_status == BF_SUCCESS);

  std::vector<uint64_t> values;
  bf_status = table_data.get()->getValue(data_id, &values);
  assert(bf_status == BF_SUCCESS);

  return values.at(pipe_id);
}

void TofinoRegister::write(uint64_t key, uint64_t value) {
  bf_status_t bf_status;

  std::unique_ptr<BfRtTableKey> table_key;
  std::unique_ptr<BfRtTableData> table_data;

  bf_status = table->keyAllocate(&table_key);
  assert(bf_status == BF_SUCCESS);

  bf_status = table->dataAllocate(&table_data);
  assert(bf_status == BF_SUCCESS);

  bf_status = table_key->setValue(reg_index_key_id, key);
  assert(bf_status == BF_SUCCESS);

  bf_status = table_data->setValue(data_id, value);
  assert(bf_status == BF_SUCCESS);

  bf_status = table->tableEntryAdd(*switchd->session, switchd->device_target,
                                   *table_key.get(), *table_data.get());
  assert(bf_status == BF_SUCCESS);
}