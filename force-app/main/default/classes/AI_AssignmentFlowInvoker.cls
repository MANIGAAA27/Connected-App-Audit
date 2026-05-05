public with sharing class AI_AssignmentFlowInvoker {
    private static final Set<String> ALLOWED_OBJECTS = new Set<String>{'Lead', 'Case', 'Task'};

    @InvocableMethod(label='AI Assignment Flow Action' description='Invoke the AI assignment engine from a flow')
    public static void assignRecordsViaFlow(List<FlowAssignmentRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        Map<String, List<sObject>> recordsByType = new Map<String, List<sObject>>();
        for (FlowAssignmentRequest request : requests) {
            if (request == null || request.recordId == null || String.isBlank(request.objectType)) {
                continue;
            }
            if (!ALLOWED_OBJECTS.contains(request.objectType)) {
                continue;
            }
            sObject record = fetchRecord(request.objectType, request.recordId);
            if (record == null) {
                continue;
            }
            if (!recordsByType.containsKey(request.objectType)) {
                recordsByType.put(request.objectType, new List<sObject>());
            }
            recordsByType.get(request.objectType).add(record);
        }
        for (String objectType : recordsByType.keySet()) {
            AI_AssignmentService.assignRecords(recordsByType.get(objectType), objectType);
        }
    }

    private static sObject fetchRecord(String objectType, Id recordId) {
        try {
            String soql = 'SELECT Id, OwnerId, Use_AI_Assignment__c FROM ' + objectType + ' WHERE Id = :recordId LIMIT 1';
            return Database.query(soql);
        } catch (Exception ex) {
            return null;
        }
    }

    public class FlowAssignmentRequest {
        @InvocableVariable(required=true)
        public Id recordId;
        @InvocableVariable(required=true)
        public String objectType;
    }
}