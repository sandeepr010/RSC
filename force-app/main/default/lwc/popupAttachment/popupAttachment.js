import { api } from 'lwc';
import LightningModal from "lightning/modal";

export default class PopupAttachment extends LightningModal  {
    @api recordId;
    @api header;

    onClose() {
    this.close("okay");
  }
}