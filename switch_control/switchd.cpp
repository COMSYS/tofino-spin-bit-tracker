/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	  Author: Ike Kunze
	  E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

#include "switchd.hpp"

#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <cstdlib>
#include <functional>
#include <thread>

Switchd::Switchd(const char *p4_name) {
  this->p4_name = p4_name;

  switchd_ctx = (bf_switchd_context_t *)calloc(1, sizeof(bf_switchd_context_t));

  if (switchd_ctx == NULL) {
    LOG_F(ERROR, "Cannot Allocate switchd context!");
    exit(1);
  }

  const char *env_sde_install = getenv("SDE_INSTALL");
  switchd_ctx->install_dir = strdup(env_sde_install);
  LOG_F(INFO, "Install Dir: %s\n", switchd_ctx->install_dir);

  char* sde_path = std::getenv("SDE");
	printf("The SDE path is: %s \n",sde_path);
	if (sde_path == nullptr) {
		printf("$SDE variable is not set\n");
		exit(0);
	}

  switchd_ctx->conf_file = (char *)malloc(256);
  sprintf(switchd_ctx->conf_file,
          "%s/build/p4-build/tofino/%s/%s/tofino/%s.conf",
          sde_path, p4_name, p4_name, p4_name);
  LOG_F(INFO, "Conf-file : %s\n", switchd_ctx->conf_file);
}

bf_status_t Switchd::start() {
  switchd_ctx->dev_sts_thread = true;
  switchd_ctx->dev_sts_port = 7777;

  switchd_ctx->kernel_pkt = true;

  bf_status_t status;
  status = bf_switchd_lib_init(switchd_ctx);
  CHECK_F(status == BF_SUCCESS, "switchd lib init failed");

  device_target.dev_id = 0;
  device_target.pipe_id = ALL_PIPES;

  auto &devMgr = bfrt::BfRtDevMgr::getInstance();
  status = devMgr.bfRtInfoGet(device_target.dev_id, p4_name, &bfrtInfo);
  assert(status == BF_SUCCESS);

  session = bfrt::BfRtSession::sessionCreate();
}