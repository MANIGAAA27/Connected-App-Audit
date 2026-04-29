public with sharing class ConnectedAppInventoryService {
    public class InventoryRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String appName;
        @AuraEnabled public String appType;
        @AuraEnabled public String status;
        @AuraEnabled public String risk;
        @AuraEnabled public Date lastUsedDate;
        @AuraEnabled public Date lastReviewDate;
        @AuraEnabled public String businessOwnerName;
        @AuraEnabled public String technicalOwnerName;
        @AuraEnabled public String ownerDisplay;
        @AuraEnabled public String notes;
    }

    public class Summary {
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer active;
        @AuraEnabled public Integer dormant;
        @AuraEnabled public Integer obsolete;
    }

    public static List<InventoryRow> fetchInventory(String searchKey, String statusFilter, Integer limitSize) {
        Integer lim = (limitSize == null || limitSize <= 0 || limitSize > 2000) ? 2000 : limitSize;

        String whereClause = 'Id != null';
        if (String.isNotBlank(searchKey)) {
            String escaped = String.escapeSingleQuotes('%' + searchKey.trim() + '%');
            whereClause += ' AND (App_Name__c LIKE \'' + escaped + '\' OR App_External_Id__c LIKE \'' + escaped + '\')';
        }
        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            String escapedStatus = String.escapeSingleQuotes(statusFilter);
            whereClause += ' AND Status__c = \'' + escapedStatus + '\'';
        }

        String soql =
            'SELECT Id, App_Name__c, App_Type__c, Status__c, Risk_Classification__c, ' +
            'Last_Used_Date__c, Last_Review_Date__c, Notes__c, ' +
            'Business_Owner__r.Name, Technical_Owner__r.Name ' +
            'FROM Connected_App_Inventory__c ' +
            'WHERE ' + whereClause + ' ' +
            'ORDER BY App_Name__c ASC ' +
            'LIMIT ' + lim;

        List<Connected_App_Inventory__c> recs = Database.query(soql + ' WITH SECURITY_ENFORCED');

        List<InventoryRow> rows = new List<InventoryRow>();
        for (Connected_App_Inventory__c rec : recs) {
            InventoryRow row = new InventoryRow();
            row.id = rec.Id;
            row.appName = rec.App_Name__c;
            row.appType = rec.App_Type__c;
            row.status = rec.Status__c;
            row.risk = rec.Risk_Classification__c;
            row.lastUsedDate = rec.Last_Used_Date__c;
            row.lastReviewDate = rec.Last_Review_Date__c;
            row.notes = rec.Notes__c;
            row.businessOwnerName = (rec.Business_Owner__r == null) ? null : rec.Business_Owner__r.Name;
            row.technicalOwnerName = (rec.Technical_Owner__r == null) ? null : rec.Technical_Owner__r.Name;

            List<String> ownerParts = new List<String>();
            if (String.isNotBlank(row.businessOwnerName)) ownerParts.add(row.businessOwnerName);
            if (String.isNotBlank(row.technicalOwnerName)) ownerParts.add(row.technicalOwnerName);
            row.ownerDisplay = ownerParts.isEmpty() ? null : String.join(ownerParts, ' / ');
            rows.add(row);
        }
        return rows;
    }

    public static Summary getSummary() {
        List<AggregateResult> agg = [
            SELECT Status__c status, COUNT(Id) cnt
            FROM Connected_App_Inventory__c
            GROUP BY Status__c
            WITH SECURITY_ENFORCED
        ];

        Summary s = new Summary();
        s.total = 0;
        s.active = 0;
        s.dormant = 0;
        s.obsolete = 0;

        for (AggregateResult ar : agg) {
            String status = (String)ar.get('status');
            Integer cnt = (Integer)ar.get('cnt');
            s.total += cnt;
            if (status == 'Active') s.active += cnt;
            else if (status == 'Dormant') s.dormant += cnt;
            else if (status == 'Obsolete') s.obsolete += cnt;
        }
        return s;
    }

    public static void validateOwnerAndPurpose(List<Connected_App_Inventory__c> newList, Map<Id, Connected_App_Inventory__c> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        for (Connected_App_Inventory__c rec : newList) {
            Connected_App_Inventory__c oldRec = (oldMap == null) ? null : oldMap.get(rec.Id);

            Boolean statusChanged = (oldRec == null) ? true : (rec.Status__c != oldRec.Status__c);

            if (statusChanged && rec.Status__c == 'Active') {
                if (rec.Business_Owner__c == null || rec.Technical_Owner__c == null || String.isBlank(rec.Business_Purpose__c)) {
                    rec.addError(System.Label.CAAG_Activate_Requires_Owners_And_Purpose);
                }
            }
        }
    }
}