import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getComplaints from '@salesforce/apex/RSCComplaintPortalHomelHandler.getComplaints';
export default class RscComplaintPortalHome extends NavigationMixin(LightningElement) {
    @track complaintList = [];
    @track showFileUpload = false;
    @track showForm = true;
    @track recordId;
    @api formHeader = 'Register Complaint';
    selectedComplaint;
    error;

    @wire(getComplaints)
    wiredGetComplaints(result) {
        this.wiredComplaintsResult = result
        const { data, error } = result;
        if (data) {
            this.complaintList = data;
            console.log('complaintList', JSON.stringify(this.complaintList));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.complaintList = [];
            console.log('error', JSON.stringify(this.error));
        }
    }

    onCardClick(event){
        const recordId = event.target.dataset.id;
        console.log('recordId', recordId);
        this[NavigationMixin.Navigate]( {
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'RSC_Complaint__c',
                actionName: 'view'
            },
        })
    }

    onRecordCreation(event){
        if(event.detail.message == 'success'){
            this.recordId = event.detail.recordId;
            this.showFileUpload = true;
            this.formHeader = 'Complaint Details';
        }
        refreshApex(this.wiredComplaintsResult);
    }

    onRefresh(){
        this.recordId = null;
        this.showFileUpload = false;
        this.showForm = false;
        this.formHeader = 'Register Complaint';
        setTimeout(() => {
            this.showForm = true;
        }, 1000);
    }
}