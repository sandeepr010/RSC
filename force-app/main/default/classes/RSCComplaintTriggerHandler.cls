public with sharing class RSCComplaintTriggerHandler {
    @InvocableMethod
    public static void sendEmailWithAttachment(List<Id> complaintIds) {
        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        Map<Id, String> emailDetails = getCustomerEmail(complaintIds);
        
        OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
        
        for (Id compId : complaintIds) {
            if(!emailDetails.containsKey(compId) || String.isBlank(emailDetails.get(compId))){
                continue;
            }
            PageReference pdfPage = Page.rscComplaintDetails;
            pdfPage.getParameters().put('id', String.valueOf(compId));
            
            Blob pdfBlob = pdfPage.getContentAsPDF();
            Messaging.EmailFileAttachment pdfAttachment = new Messaging.EmailFileAttachment();
            pdfAttachment.setFileName('Complaint_Details.pdf');
            pdfAttachment.setBody(pdfBlob);
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(emailDetails.get(compId));
            //email.setToAddresses(new List<String>{'1sandeepr1@gmail.com'});
            email.setSubject('Your Complaint Details');
            email.setPlainTextBody('Please find attached your complaint details.');
            email.setFileAttachments(new List<Messaging.EmailFileAttachment>{pdfAttachment});
            email.setOrgWideEmailAddressId(owea.Id);
            
            email.setTreatTargetObjectAsRecipient(true);
            email.setSaveAsActivity(false);
            // email.setUseSignature(false);
            // email.setBccSender(false);
            
            emails.add(email);
        }
        
        if(emails.isEmpty()){
            return;
        }
        
        Messaging.sendEmail(emails);
    }
    
    private static Map<Id, String> getCustomerEmail(List<Id> complaintIds) {
        Map<Id, String> emailDetails = new Map<Id, String>();
        for(RSC_Complaint__c comp : [SELECT Id, Owner.Email, OwnerId FROM RSC_Complaint__c WHERE Id IN:complaintIds WITH SECURITY_ENFORCED]){
            emailDetails.put(comp.Id, comp.OwnerId);
        }
        
        return emailDetails;
    }
}