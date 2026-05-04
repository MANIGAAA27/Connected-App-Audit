import { LightningElement, wire } from 'lwc';
import fetchStrategies from '@salesforce/apex/AI_AssignmentAdminController.fetchStrategies';

const COLUMNS = [
    { label: 'Name', fieldName: 'name' },
    { label: 'Objective', fieldName: 'objective' },
    { label: 'Performance Weight', fieldName: 'weightPerformance', type: 'percent' },
    { label: 'Workload Weight', fieldName: 'weightWorkload', type: 'percent' },
    { label: 'Skill Weight', fieldName: 'weightSkill', type: 'percent' },
    { label: 'Enabled', fieldName: 'enabled', type: 'boolean' },
    { label: 'Object Target', fieldName: 'objectTarget' }
];

export default class AiAssignmentAdmin extends LightningElement {
    columns = COLUMNS;
    strategies;
    error;
    isLoading = true;

    @wire(fetchStrategies)
    wiredStrategies({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.strategies = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Unable to load strategies';
            this.strategies = undefined;
        }
    }
}
