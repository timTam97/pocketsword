/*
 *  PocketSwordStatusReporter.cpp
 *  PocketSword
 *
 *  Created by Nic Carter on 26/09/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#include <swlog.h>
#include "PocketSwordStatusReporter.h"

PocketSwordStatusReporter::PocketSwordStatusReporter() {
	overallProgress = 0.0;
	fileProgress = 0.0;
	totalBytesReported = 0.0;
	completedBytesReported = 0.0;
	description = new sword::SWBuf("");
}
	
/** called before stages of a batch download */
void PocketSwordStatusReporter::preStatus(long totalBytes, long completedBytes, const char *message) {
	completedBytesReported = completedBytes;
	totalBytesReported = totalBytes;
	overallProgress = (float)completedBytes / (float)totalBytes;
	if(overallProgress >= 1.0) {
		overallProgress = 0.9999;
	}
	description = new sword::SWBuf(message);
	//sword::SWLog::getSystemLog()->logError("==========\nPRESTATUS(totalBytes = %d, competedBytes = %d, message = %s) = %f\n==========", totalBytes, completedBytes, message, overallProgress);
}
	
/** frequently called throughout a download, to report status */
void PocketSwordStatusReporter::statusUpdate(double dtTotal, double dlNow) {
	fileProgress = dlNow / dtTotal;
	if(fileProgress >= 1.0) {
		fileProgress = 0.9999;
	}
	overallProgress = (float)(completedBytesReported + dlNow) / (float) (totalBytesReported);
	if(overallProgress >= 1.0) {
		overallProgress = 0.9999;
	}
	//sword::SWLog::getSystemLog()->logError("==========STATUSUPDATE(dtTotal = %f, dlNow = %f) = %f==========", dtTotal, dlNow, fileProgress);
}

const char* PocketSwordStatusReporter::getDescription() {
	return description->c_str();
}

