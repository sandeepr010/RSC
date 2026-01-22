import { LightningElement } from 'lwc';
import Subject from '@salesforce/schema/RSC_Complaint__c.Subject__c';
import Complaint_Category from '@salesforce/schema/RSC_Complaint__c.RSC_Complaint_Category__c';
import Complaint_Description from '@salesforce/schema/RSC_Complaint__c.Complaint_Description__c';
export default class RscComplaintFrom extends LightningElement {
    objectApiName = 'RSC_Complaint__c';
    fields = [Subject, Complaint_Category, Complaint_Description];

    handleSubmit(event){
        event.preventDefault();
        const fields = event.detail.fields;
        console.log('fields : '+JSON.stringify(fields));
        if(fields.Subject__c == null || fields.Subject__c.length == 0){
            window.alert("Subject is required.");
            return;
        }
        if(fields.RSC_Complaint_Category__c == null || fields.RSC_Complaint_Category__c.length == 0){
            window.alert("Please select Complaint Category.");
            return;
        }
        if(fields.Complaint_Description__c == null || fields.Complaint_Description__c.length == 0){
            window.alert("Please share details about the complaint in Description.");
            return;
        }
        fields.Complaint_Origin__c = 'Portal';
        //fields.Priority__c = 'Medium';
        this.template.querySelector('lightning-record-form').submit(fields);
    }

    onSuccess(event){
        console.log('Record saved successfully:', event.detail.id);
        window.alert('Complaint raised successfully.');
        const custEvent = new CustomEvent('success', {
            detail: {
                message: 'success',
                recordId: event.detail.id
            }
        });
        this.dispatchEvent(custEvent);
        //window.location.reload();
    }
}