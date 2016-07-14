/*
 * Utility class for building SOQL string that mimicks SOSL search capability, but includes numbers and dates.
 *
 * Usage:  List<sObject> = Database.query(SearchUtil.buildSearchAllFieldsQuery(searchTerm, obectName, fieldSetName));
 * searchTerm:  String containing the search term.  Can be numbers, string, or date that matches locale.
 * objectName:  This is the API name, such as ExtraInfo__c or CSU__ExtraInfo__c
 * fieldSetName:  The utility uses a fieldset to govern both which fields to return, and which fields to search.
 *
 * TLaPorte
 */

public with sharing class SearchUtil {

    private static final String LONG_TYPE = 'Long';
    private static final String STRING_TYPE = 'String';
    private static final String DATETIME_TYPE = 'Datetime';
    private static final String DATE_TYPE = 'Date';
    private static final String DOUBLE_TYPE = 'Double';

    public static String buildSearchAllFieldsQuery (String searchTerm, String objectName, String fieldSetName) {
        DescribeCache cache = DescribeCache.getDescribeCache(objectName);

        // Detect the type of value passed in for the search term -
        String searchTermType = STRING_TYPE;
        Boolean foundAType = false;
        Object searchTypedValue = searchTerm;
        try {
            searchTypedValue = Datetime.parse(searchTerm);
            searchTermType = DATETIME_TYPE;
            foundAType = true;
        } catch (Exception e) {
            system.debug(e.getMessage());
        }
        try {
            if (foundAType) {
                throw new SearchUtilException('Already identified a(n):  '+searchTermType);
            }
            searchTypedValue = Date.parse(searchTerm);
            searchTermType = DATE_TYPE;
            foundAType = true;
        } catch (Exception e) {
            system.debug(e.getMessage());
        }
        try {
            String searchString = searchTerm.remove(',');
            if (foundAType) {
                throw new SearchUtilException('Already identified a(n):  '+searchTermType);
            }
            searchTypedValue = Long.valueOf(searchString);
            searchTermType = LONG_TYPE;
            searchTerm = searchString;
            foundAType = true;
        } catch (Exception e) {
            system.debug(e.getMessage());
        }
        try {
            String searchString = searchTerm.remove(',');
            if (foundAType) {
                throw new SearchUtilException('Already identified a(n):  '+searchTermType);
            }
            searchTypedValue = Double.valueOf(searchString);
            searchTermType =  DOUBLE_TYPE;
            searchTerm = searchString;
            foundAType = true;
        } catch (Exception e) {
            system.debug(e.getMessage());
        }

        String queryString = 'SELECT ';
        for (String fieldName : SObjectUtil.getFieldsFromFieldSet(objectName, fieldSetName, false)) {
            queryString += fieldName + ',';
        }
        queryString = queryString.removeEnd(','); // Remove the last comma

        queryString += ' FROM ' + objectName;
        queryString += ' WHERE Id != null AND (';  // Simple where clause will always be true, so we can simply add 'OR' statements from here on out
        String orClause = '';
        for (String fieldName : cache.getFieldMap().keySet()) {
            Schema.DescribeFieldResult fieldDescribe = cache.getFieldDescribe(fieldName);

            if (DATE_TYPE.equalsIgnoreCase(searchTermType)) {
                if (fieldDescribe.getType() == Schema.DisplayType.Date) {
                    orClause += addDateClause(fieldName, searchTerm, searchTypedValue);
                }
            } else if (DATETIME_TYPE.equalsIgnoreCase(searchTermType)) {
                if (fieldDescribe.getType() == Schema.DisplayType.DateTime) {
                    orClause += addDatetimeClause(fieldName, searchTerm, searchTypedValue);
                }
            } else if (LONG_TYPE.equalsIgnoreCase(searchTermType)) {
                if (fieldDescribe.getType() == Schema.DisplayType.Percent) {
                    orClause += addNumberClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Integer) {
                    orClause += addNumberClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Double) {
                    orClause += addIntToDoubleClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Currency) {
                    orClause += addNumberClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Email) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.String) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Phone) {
                    orClause += addStringClause(fieldName, searchTerm);
                }
            } else if (DOUBLE_TYPE.equalsIgnoreCase(searchTermType)) {
                if (fieldDescribe.getType() == Schema.DisplayType.Percent) {
                    orClause += addNumberClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Integer) {
                    orClause += addNumberClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Double) {
                    orClause += addNumberClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Currency) {
                    orClause += addNumberClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Email) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.String) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Phone) {
                    orClause += addStringClause(fieldName, searchTerm);
                }
            } else if (STRING_TYPE.equalsIgnoreCase(searchTermType)) {
                if (fieldDescribe.getType() == Schema.DisplayType.Email) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.String) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    orClause += addStringClause(fieldName, searchTerm);
                } else if (fieldDescribe.getType() == Schema.DisplayType.Phone) {
                    orClause += addStringClause(fieldName, searchTerm);
                }
            }
        }

        orClause = orClause.trim().removeStart('OR'); // Remove the first 'OR' if it exists

        queryString += orClause + ')';

        // If query didn't end up getting an OR clause, return zero records, so let's break the query.
        if (queryString.endsWith('AND ()')) {
            queryString = 'SELECT Id FROM ' + objectName + ' WHERE Id = null';
        }

        system.debug('Generated Query:  '+queryString);

        return queryString;
    }

    private static String addStringClause (String fieldName, String searchTerm) {
        return ' OR ' + fieldName + ' LIKE \'%' + searchTerm +'%\'';
    }

    private static String addNumberClause (String fieldName, String searchTerm) {
        return ' OR ' + fieldName + ' = ' + searchTerm +'';
    }

    private static String addIntToDoubleClause(String fieldName, String searchTerm) {
        String clause = ' OR ' + fieldName + ' = ' + searchTerm;
        if (!searchTerm.contains('.')) {
            clause += '.00';
        }
        return clause;
    }

    private static String addDateClause (String fieldName, String searchTerm, Object searchTypedValue) {
        return ' OR ' + fieldName + ' = ' + ((Datetime)searchTypedValue).format('yyyy-MM-dd') + 'T00:00:00Z';
    }

    private static String addDatetimeClause (String fieldName, String searchTerm, Object searchTypedValue) {
        Datetime thisDatetime = (Datetime)searchTypedValue;

        Integer offSetMinutes = DateTimeUtil.getTimezoneOffsetMinutesForCurrentUser(thisDatetime);

        system.debug('Offset Minutes:  '+offSetMinutes);

        // Multiplying by -1 to bring our datetime back in line with GMT,
        // Ex:  10am PDT on 11/4 will return a -8 difference, so we want to add 8 hours to get to GMT (GMT stored in DB)
        // Ex:  10am 'France' time (+1, I have no idea) will return a +1 hour difference, so we need to subtract 1 hour to get to GMT
        Datetime offsetDatetime = thisDatetime.addMinutes(-1*offSetMinutes);

        // I highly doubt customers are going to type in seconds for their search, so I am assuming :00 will be returned from the format string.  Hardly ever\
        // will this match, so I am adding a minute and checking between.
        return ' OR (' + fieldName + ' > ' + offsetDatetime.format('yyyy-MM-dd') + 'T' + offsetDatetime.format('HH:mm:ss') + 'Z AND '
                + fieldName + ' < ' + offsetDatetime.format('yyyy-MM-dd') + 'T' + offsetDatetime.addMinutes(1).format('HH:mm:ss') + 'Z) ';
    }

    private class SearchUtilException extends Exception {}
}
