/*
 *  PocketSwordStatusReporter.h
 *  PocketSword
 *
 *  Created by Nic Carter on 26/09/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#include <ftptrans.h>
#include <swbuf.h>

class PocketSwordStatusReporter : public sword::StatusReporter {
public:
	
	float overallProgress, fileProgress, totalBytesReported, completedBytesReported;
	sword::SWBuf *description;
    PocketSwordStatusReporter();
	
    /** called before stages of a batch download */
    void preStatus(long totalBytes, long completedBytes, const char *message);
	
    /** frequently called throughout a download, to report status */
    void statusUpdate(double dtTotal, double dlNow);
	
	const char* getDescription();
};
