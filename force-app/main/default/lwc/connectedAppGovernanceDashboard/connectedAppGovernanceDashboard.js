import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getInventory from '@salesforce/apex/ConnectedAppInventoryController.getInventory';
import getSummary from '@salesforce/apex/ConnectedAppInventoryController.getSummary';

import CAAG_Dashboard_Title from '@salesforce/label/c.CAAG_Dashboard_Title';
import CAAG_Search_Label from '@salesforce/label/c.CAAG_Search_Label';
import CAAG_Status_Filter from '@salesforce/label/c.CAAG_Status_Filter';
import CAAG_Refresh from '@salesforce/label/c.CAAG_Refresh';
import CAAG_No_Results from '@salesforce/label/c.CAAG_No_Results';
import CAAG_Close from '@salesforce/label/c.CAAG_Close';
import CAAG_Record_Details from '@salesforce/label/c.CAAG_Record_Details';
import CAAG_Open_Record from '@salesforce/label/c.CAAG_Open_Record';

import CAAG_Metric_Total from '@salesforce/label/c.CAAG_Metric_Total';
import CAAG_Metric_Active from '@salesforce/label/c.CAAG_Metric_Active';
import CAAG_Metric_Dormant from '@salesforce/label/c.CAAG_Metric_Dormant';
import CAAG_Metric_Obsolete from '@salesforce/label/c.CAAG_Metric_Obsolete';

import CAAG_Col_AppName from '@salesforce/label/c.CAAG_Col_AppName';
import CAAG_Col_Status from '@salesforce/label/c.CAAG_Col_Status';
import CAAG_Col_Risk from '@salesforce/label/c.CAAG_Col_Risk';
import CAAG_Col_LastUsed from '@salesforce/label/c.CAAG_Col_LastUsed';
import CAAG_Col_LastReview from '@salesforce/label/c.CAAG_Col_LastReview';
import CAAG_Col_Owner from '@salesforce/label/c.CAAG_Col_Owner';
import CAAG_Row_Action from '@salesforce/label/c.CAAG_Row_Action';
import CAAG_Row_View from '@salesforce/label/c.CAAG_Row_View';

import CAAG_Field_AppName from '@salesforce/label/c.CAAG_Field_AppName';
import CAAG_Field_Type from '@salesforce/label/c.CAAG_Field_Type';
import CAAG_Field_Status from '@salesforce/label/c.CAAG_Field_Status';
import CAAG_Field_Risk from '@salesforce/label/c.CAAG_Field_Risk';
import CAAG_Field_BusinessOwner from '@salesforce/label/c.CAAG_Field_BusinessOwner';
import CAAG_Field_TechnicalOwner from '@salesforce/label/c.CAAG_Field_TechnicalOwner';
import CAAG_Field_LastUsed from '@salesforce/label/c.CAAG_Field_LastUsed';
import CAAG_Field_LastReview from '@salesforce/label/c.CAAG_Field_LastReview';
import CAAG_Field_Notes from '@salesforce/label/c.CAAG_Field_Notes';

export default class ConnectedAppGovernanceDashboard extends NavigationMixin(LightningElement) {
    labels = {
        CAAG_Dashboard_Title,
        CAAG_Search_Label,
        CAAG_Status_Filter,
        CAAG_Refresh,
        CAAG_No_Results,
        CAAG_Close,
        CAAG_Record_Details,
        CAAG_Open_Record,
        CAAG_Metric_Total,
        CAAG_Metric_Active,
        CAAG_Metric_Dormant,
        CAAG_Metric_Obsolete,
        CAAG_Field_AppName,
        CAAG_Field_Type,
        CAAG_Field_Status,
        CAAG_Field_Risk,
        CAAG_Field_BusinessOwner,
        CAAG_Field_TechnicalOwner,
        CAAG_Field_LastUsed,
        CAAG_Field_LastReview,
        CAAG_Field_Notes
    };

    @track rows;
    @track summary;
    @track error;

    searchKey = '';
    statusFilter = 'All';

    isModalOpen = false;
    selectedRecord;

    columns = [
        { label: CAAG_Col_AppName, fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'appName' }, target: '_blank' } },
        { label: CAAG_Col_Status, fieldName: 'status', type: 'text' },
        { label: CAAG_Col_Risk, fieldName: 'risk', type: 'text' },
        { label: CAAG_Col_Owner, fieldName: 'ownerDisplay', type: 'text' },
        { label: CAAG_Col_LastUsed, fieldName: 'lastUsedDate', type: 'date' },
        { label: CAAG_Col_LastReview, fieldName: 'lastReviewDate', type: 'date' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: CAAG_Row_View, name: 'view' }
                ],
                menuAlignment: 'right'
            },
            label: CAAG_Row_Action
        }
    ];

    get statusOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Active', value: 'Active' },
            { label: 'Dormant', value: 'Dormant' },
            { label: 'Obsolete', value: 'Obsolete' }
        ];
    }

    connectedCallback() {
        void this.refreshData();
    }

    async refreshData() {
        this.error = undefined;
        try {
            const [inv, sum] = await Promise.all([
                getInventory({ searchKey: this.searchKey, statusFilter: this.statusFilter }),
                getSummary()
            ]);
            this.rows = (inv || []).map(r => ({
                id: r.id,
                appName: r.appName,
                status: r.status,
                risk: r.risk,
                lastUsedDate: r.lastUsedDate,
                lastReviewDate: r.lastReviewDate,
                ownerDisplay: r.ownerDisplay,
                recordUrl: '/' + r.id,
                businessOwnerName: r.businessOwnerName,
                technicalOwnerName: r.technicalOwnerName,
                appType: r.appType,
                notes: r.notes
            }));
            this.summary = sum;
        } catch (e) {
            this.error = (e && e.body && e.body.message) ? e.body.message : (e ? e.message : 'Unknown error');
            this.rows = undefined;
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        void this.refreshData();
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
        void this.refreshData();
    }

    handleRefresh() {
        void this.refreshData();
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'view') {
            this.selectedRecord = row;
            this.isModalOpen = true;
        }
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedRecord = undefined;
    }

    navigateToRecord() {
        if (!this.selectedRecord) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedRecord.id,
                objectApiName: 'Connected_App_Inventory__c',
                actionName: 'view'
            }
        });
    }
}