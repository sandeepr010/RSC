trigger ComplaintTrigger on RSC_Complaint__c (before update) {
    ComplaintTrigger.handler();
}