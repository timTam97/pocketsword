/*
 *  PSStatusReporter.cpp
 *  PocketSword
 *
 *  Created by Nic Carter on 26/09/09.
 *  Copyright 2009 The CrossWire Bible Society. All rights reserved.
 *
 */

#include <swlog.h>
#include "PSStatusReporter.h"

PSStatusReporter::PSStatusReporter() {
	overallProgress = 0.0;
	fileProgress = 0.0;
	totalBytesReported = 0.0;
	completedBytesReported = 0.0;
	//description = new sword::SWBuf("");
	//description = NULL;
	des = NULL;
}

PSStatusReporter::~PSStatusReporter() {
	//delete description;
}
	
/** called before stages of a batch download */
void PSStatusReporter::preStatus(long totalBytes, long completedBytes, const char *message) {
	completedBytesReported = completedBytes;
	totalBytesReported = totalBytes;
	overallProgress = (float)completedBytes / (float)totalBytes;
	if(overallProgress >= 1.0) {
		overallProgress = 0.9999;
	}
	des = message;
//	description = NULL;
//	delete description;
//	description = new sword::SWBuf(message);
	//sword::SWLog::getSystemLog()->logError("==========\nPRESTATUS(totalBytes = %d, competedBytes = %d, message = %s) = %f\n==========", totalBytes, completedBytes, message, overallProgress);
}
	
/** frequently called throughout a download, to report status */
void PSStatusReporter::statusUpdate(double dtTotal, double dlNow) {
	fileProgress = dlNow / dtTotal;
	if(fileProgress >= 1.0) {
		fileProgress = 0.9999;
	}
	overallProgress = (float)(completedBytesReported + dlNow) / (float) (totalBytesReported);
	if(overallProgress >= 1.0) {
		overallProgress = 0.9999;
	}
	//sword::SWLog::getSystemLog()->logError("==========STATUSUPDATE(dtTotal = %.0f, dlNow = %.0f) = %f==========", dtTotal, dlNow, fileProgress);
}

const char* PSStatusReporter::getDescription() {
	if(des)
		return des;
	else
		return "";
//	if(description)
//		return description->c_str();
//	else
//		return "";
}

