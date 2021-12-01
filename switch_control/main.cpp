/*
    Spin Tracker for Tofino
    Copyright (c) 2021 
	
	Author: Ike Kunze
	E-mail: kunze@comsys.rwth-aachen.de
    Use of this source code is governed the MIT License.
*/

#include "tofino_switch_control.hpp"
#include <chrono>
#include <thread>
#include <cmath>
#include <math.h>
#include <iostream>
#include <vector>
#include <numeric>
#include <fstream>
#include <getopt.h>
#include <sys/time.h> 

#include <signal.h>
#include <iomanip>

TofinoSwitchControl* tsc;

bool LOOP_RUNNING = true;

void stopTheMainLoop(int sig_num) {
   std::cout << "Interrupt signal (" << sig_num << ") received." << std::endl;
   LOOP_RUNNING = false;
}


int main(int argc, char** argv) {

	std::string file_path;
	bool spinbit_enabled = false;
  	int spinbit_reorderingprotection = 0;
	int pipe_id = 1;
	int readout_sleep_ms = 5;
	int configured_rtt = 0;
	int min_latency = 0;
	int max_latency = 0;

	static const struct option long_options[] =
    {
        { "file", 						required_argument,		0, 'f' },
        { "spin_enabled", 				no_argument,       		0, 's' },
        { "spin_reorderprotection", 	required_argument, 		0, 'r' },
        { "pipe_id", 					required_argument, 		0, 'p' },
        { "readout_sleep_ms", 			required_argument, 		0, 'c' },
        { "configured_rtt", 			required_argument, 		0, 'd' },
		{ "min_latency", 				required_argument, 		0, 'm' },
        { "max_latency", 				required_argument, 		0, 'n' },
        0
    };

	while (true)
    {

        const auto opt = getopt_long(argc, argv, "f:sr:p:c:d:m:n:", long_options, nullptr);

        if (-1 == opt)
            break;

        switch (opt)
        {
        case 'f':
            file_path = std::string(optarg);
			std::cout << "Use file: " << file_path <<  std::endl;
            break;

        case 's':
            spinbit_enabled = true;
            std::cout << "Spinbit is enabled" << std::endl;
            break;

        case 'r':
			spinbit_reorderingprotection = std::atoi(optarg);
			std::cout << "Use the following reorder protection " << std::to_string(spinbit_reorderingprotection) << std::endl;
            break;

        case 'p':
			pipe_id = std::atoi(optarg);
			std::cout << "Use pipe ID " << std::to_string(pipe_id) << std::endl;
            break;

        case 'c':
			readout_sleep_ms = std::atoi(optarg);
			std::cout << "Use readout_sleep_ms " << std::to_string(readout_sleep_ms) << std::endl;
            break;

		case 'd':
			configured_rtt = std::atoi(optarg);
			std::cout << "An RTT of " << std::to_string(configured_rtt) << " was configured." << std::endl;
            break;


		case 'm':
			min_latency = std::atoi(optarg);
			std::cout << "A minimum value of " << std::to_string(min_latency) << " was configured." << std::endl;
            break;


		case 'n':
			max_latency = std::atoi(optarg);
			std::cout << "A maximum value of " << std::to_string(max_latency) << " was configured." << std::endl;
            break;

        case 'h': // -h or --help
        case '?': // Unrecognized option
        default:
            std::cout << "Default" << std::endl;
            break;
        }
    }

	std::cout << "Spin-Bit Measurements ";
	if(spinbit_enabled){
		std::cout << "enabled." << std::endl;
	} else{
		std::cout << "disabled." << std::endl;
	}
	std::cout << "Spin-Bit Reorder Protection: ";
	if(spinbit_reorderingprotection == 1){
		std::cout << " Qbit-Variant." << std::endl;
	} else if (spinbit_reorderingprotection == 2){
		std::cout << " Consec-Variant." << std::endl;
	} else{
		std::cout << " Disabled." << std::endl;
	}

	tsc = new TofinoSwitchControl(file_path, spinbit_enabled, spinbit_reorderingprotection);
	tsc->initializeDataplaneInterfaces();
	tsc->setupDataplane();
	tsc->setSpinReorderProtection();


	struct sigaction sigHandler;

	sigHandler.sa_handler = stopTheMainLoop;
	sigemptyset(&sigHandler.sa_mask);
	sigHandler.sa_flags = 0;

	sigaction(SIGINT, &sigHandler, NULL);
	sigaction(SIGTERM, &sigHandler, NULL);
	sigaction(SIGHUP, &sigHandler, NULL);

	std::ofstream statsFile (file_path);
	if (statsFile.is_open()){
		std::cout << "Stats output file is ready" << std::endl;
		statsFile << "timestamp_us, spinbit_counter, spinbit_RTT, spinbit_ringbuffer, spinbit_raw, class0_curr, class0_sum, class1_curr, class1_sum, class2_curr, class2_sum\n";
	}

	uint16_t spin_RTT_value_uint = 0;
	uint16_t spin_measurements_uint = 0;
	uint16_t spin_ring_accumulator_uint = 0;
	uint16_t spin_raw_uint = 0;

	uint16_t spin_class_values_0class_sum_uint = 0;
	uint16_t spin_class_values_1class_sum_uint = 0;
	uint16_t spin_class_values_2class_sum_uint = 0;
	uint8_t spin_class_values_0class_uint = 0;
	uint8_t spin_class_values_1class_uint = 0;
	uint8_t spin_class_values_2class_uint = 0;
	uint8_t spin_class_values_0class_uint_prev = 0;
	uint8_t spin_class_values_1class_uint_prev = 0;
	uint8_t spin_class_values_2class_uint_prev = 0;

  	auto current_time = std::chrono::system_clock::now();
	std::time_t time_string;
	struct tm * timeStruct;
	char time_Char[25];


	std::cout << "RTT Classification Table: " << std::endl;
	std::cout << "Grease Detection until " << 5 << "ms." << std::endl;
	tsc->RTTClassTableSetEntry((uint16_t) 0, (uint16_t) 0xFFFF, (uint16_t) 0, (uint16_t) 5, 0);

	if (min_latency != 0 && max_latency != 0) {
		std::cout << "Configure custom range." << std::endl;
		std::cout << "Expected range: (" << (uint16_t)(4 * min_latency) <<  ", " << (uint16_t)(4 * max_latency) << ") , (" << (uint16_t)(min_latency) << ", " << (uint16_t)(max_latency) << ")." << std::endl;
		tsc->RTTClassTableSetEntry((uint16_t) (4 * min_latency), (uint16_t) (4 * max_latency), (uint16_t) (min_latency), (uint16_t) (max_latency), 1);

	} else{
		std::cout << "Expected range: (" << (uint16_t)(0.9 * 4 * configured_rtt) <<  ", " << (uint16_t)(1.1 * 4 * configured_rtt) << ") , (" << (uint16_t)(0.9 * configured_rtt) << ", " << (uint16_t)(1.1 * configured_rtt) << ")." << std::endl;
		tsc->RTTClassTableSetEntry((uint16_t) (0.9 * 4 * configured_rtt), (uint16_t) (1.1 * 4 * configured_rtt), (uint16_t) (0.9 * configured_rtt), (uint16_t) (1.1 * configured_rtt), 1);
	}

	int counter = 0;
  	while (LOOP_RUNNING) {

		if (spinbit_enabled){
			spin_RTT_value_uint = (uint16_t) tsc->spin_measurement_register->read(0, pipe_id);

			spin_measurements_uint = (uint16_t) tsc->spin_measurement_counter_register->read(0, pipe_id);

			spin_ring_accumulator_uint = (uint16_t) tsc->spin_ring_buffer_register->read(0, pipe_id);

			spin_raw_uint = (uint16_t) tsc->spin_raw_timestamp_register->read(0, pipe_id);

			spin_class_values_0class_uint = (uint8_t) tsc->spin_rtt_class_counter_register->read(0, pipe_id);
			spin_class_values_1class_uint = (uint8_t) tsc->spin_rtt_class_counter_register->read(1, pipe_id);
			spin_class_values_2class_uint = (uint8_t) tsc->spin_rtt_class_counter_register->read(2, pipe_id);
		}


		if (spin_class_values_0class_uint != spin_class_values_0class_uint_prev){
			if (spin_class_values_0class_uint < spin_class_values_0class_uint_prev){
				spin_class_values_0class_sum_uint += (255 - (spin_class_values_0class_uint_prev - spin_class_values_0class_uint));
			} else{
				spin_class_values_0class_sum_uint += (spin_class_values_0class_uint - spin_class_values_0class_uint_prev);
			}
			spin_class_values_0class_uint_prev = spin_class_values_0class_uint;
		}

		if (spin_class_values_1class_uint != spin_class_values_1class_uint_prev){
			
			if (spin_class_values_1class_uint < spin_class_values_1class_uint_prev){
				spin_class_values_1class_sum_uint += (255 - (spin_class_values_1class_uint_prev - spin_class_values_1class_uint));
			} else{
				spin_class_values_1class_sum_uint += (spin_class_values_1class_uint - spin_class_values_1class_uint_prev);
			}
			spin_class_values_1class_uint_prev = spin_class_values_1class_uint;
		}

		if (spin_class_values_2class_uint != spin_class_values_2class_uint_prev){
			if (spin_class_values_2class_uint < spin_class_values_2class_uint_prev){
				spin_class_values_2class_sum_uint += (255 - (spin_class_values_2class_uint_prev - spin_class_values_2class_uint));
			} else{
				spin_class_values_2class_sum_uint += (spin_class_values_2class_uint - spin_class_values_2class_uint_prev);
			}
			spin_class_values_2class_uint_prev = spin_class_values_2class_uint;
		}

		current_time = std::chrono::system_clock::now();
		time_string = std::chrono::system_clock::to_time_t(current_time);
		timeStruct = localtime(&time_string);

		strftime(time_Char, 25, "%Y-%m-%d %H:%M:%S", timeStruct);

		struct timeval timeStamp;
		gettimeofday(&timeStamp, NULL);
		unsigned long long us = timeStamp.tv_usec;
		std::string timestampString = std::to_string(us);

		if (statsFile.is_open()){
			statsFile << time_Char << std::right << std::setfill('0') << std::setw(6) << timestampString;
			statsFile << "," << spin_measurements_uint << "," << spin_RTT_value_uint << "," << spin_ring_accumulator_uint << "," << spin_raw_uint << "," << std::to_string(spin_class_values_0class_uint) << "," << spin_class_values_0class_sum_uint  << "," << std::to_string(spin_class_values_1class_uint) << "," << spin_class_values_1class_sum_uint << "," << std::to_string(spin_class_values_2class_uint) << "," << spin_class_values_2class_sum_uint << "\n";
			statsFile.flush();
		}else{
			std::cout << "Something wrong with the stats file." << std::endl;
		}
		std::this_thread::sleep_for(std::chrono::milliseconds(readout_sleep_ms));
	}
	return 0;
}