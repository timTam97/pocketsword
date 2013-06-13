/*
 *  PSStatusReporter.h
 *  PocketSword
 *
 *  Created by Nic Carter on 26/09/09.
 *  Copyright 2009 The CrossWire Bible Society. All rights reserved.
 *
 */

#include <remotetrans.h>

class PSStatusReporter : public sword::StatusReporter {
public:
	
	float overallProgress, fileProgress, totalBytesReported, completedBytesReported;
	//sword::SWBuf *description;
	const char *des;
    PSStatusReporter();
	
    /** called before stages of a batch download */
    void preStatus(long totalBytes, long completedBytes, const char *message);
	
    /** frequently called throughout a download, to report status */
    void statusUpdate(double dtTotal, double dlNow);
	
	const char* getDescription();

	virtual ~PSStatusReporter();
};
