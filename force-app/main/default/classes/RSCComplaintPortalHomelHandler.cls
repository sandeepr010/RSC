/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : RSCComplaintPortalHomelHandler
 * Author          : Sandeep.R
 * Created Date    : Jan 15, 2026
 * Last Modified By: Sandeep.R
 * Last Modified On: Jan 15, 2026
 * Description     : Handler class for rscComplaintPortalHomel LWC Component
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 15, 2026  │ Sandeep.R    │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class RSCComplaintPortalHomelHandler {

	@AuraEnabled(cacheable=true)
	public static List<RSC_Complaint__c> getComplaints() {
		List<RSC_Complaint__c> complaintList = [SELECT Id, Name, Subject__c, Complaint_Description__c, Status__c, RSC_Complaint_Category__r.Name, RSC_Complaint_Category__r.Category_Label__c FROM RSC_Complaint__c WITH SECURITY_ENFORCED ORDER BY Name DESC];
		return complaintList;
	}

}