import { LightningElement, api, track } from 'lwc';

export default class RscAttachment extends LightningElement {
    @api recordId;
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx'];
    @track uploadedFiles;

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        console.log('Uploaded Files:', uploadedFiles);
        uploadedFiles.forEach(element => {
            this.uploadedFiles = this.uploadedFiles ? this.uploadedFiles += ', ' + element.name : element.name;
        });
    }
}