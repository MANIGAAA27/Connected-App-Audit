import { LightningElement, api, wire } from 'lwc';
import fetchLogs from '@salesforce/apex/AI_AssignmentRationaleController.fetchLogs';

export default class AssignmentRationale extends LightningElement {
    @api recordId;
    logEntries;
    error;
    isLoading = true;

    @wire(fetchLogs, { recordId: '$recordId' })
    wiredLogs({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.logEntries = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Unable to load rationale';
            this.logEntries = undefined;
        }
    }
}