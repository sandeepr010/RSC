import { LightningElement, wire, api, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import attchmentModal from "c/popupAttachment";
import Complaint_OBJECT from '@salesforce/schema/RSC_Complaint__c';
import Name from '@salesforce/schema/RSC_Complaint__c.Name';
import Status from '@salesforce/schema/RSC_Complaint__c.Status__c';
import Subject from '@salesforce/schema/RSC_Complaint__c.Subject__c';
import Description from '@salesforce/schema/RSC_Complaint__c.Complaint_Description__c';

const FIELDS = [
    'RSC_Complaint__c.Is_Approved__c',
    'RSC_Complaint__c.Status__c'
];

export default class RscComplaintUpdate extends LightningElement {
    @api recordId;
    @track enableEditFrom = false;
    objectApiName = Complaint_OBJECT;
    name = Name;
    status = Status;
    subject = Subject;
    description = Description;
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx'];

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    caseRecord;

    get showEditButton() {
        return this.caseRecord.data && (this.caseRecord.data.fields.Status__c.value === 'Awaiting Info' || this.caseRecord.data.fields.Status__c.value === 'New');
    }

    get openModal() {
        return this.showEditButton && (this.enableEditFrom || this.showSpinner);
    }

    get modalHeader() {
        return this.enableEditFrom ? 'Update Details' : 'Loading.....';
    }

    onUpdateDetails() {
        this.enableEditFrom = true;
    }

    async onAttachment() {
        const result = await attchmentModal.open({
            recordId: this.recordId,
            header: "Upload Supporting Documents",
            size: "large",
            description: "Upload Supporting Documents"
        });

        console.log('result', result);
        //window.location.reload();
    }

    handleError(event) {
        if (event.detail && event.detail.message === 'The requested resource does not exist') {
            this.showSpinner = true;
            this.enableEditFrom = false;
            setTimeout(() => {
                this.enableEditFrom = true;
                this.showSpinner = false;
            }, 2000);
        } else {
            this.enableEditFrom = true;
            this.showSpinner = false;
        }
    }

    onSuccess(event) {
        this.enableEditFrom = false;
        window.alert("Complaint is updated.");
        //window.location.reload();
    }

    onClose() {
        this.enableEditFrom = false;
    }
}