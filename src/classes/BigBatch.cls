global class BigBatch implements Database.Batchable < String > , Database.stateful {

	global Iterable < String > start(Database.BatchableContext bc) {
		return new CSVIterator([SELECT Body FROM Attachment WHERE Name = 'largedoc.csv'][0].Body.toString(), '\n');
	}

	global void execute(Database.BatchableContext BC, List < String > scope) {
		for (String s : scope) {
			system.debug('Found a string: ' + s);
		}
	}

	global void finish(Database.BatchableContext BC) {
		system.debug('We finished!');
	}

	global class CSVIterator implements Iterator < String > ,
	Iterable < String > {
		private String CSVData;
		private String lineFeedChar;

		public CSVIterator(String fileData, String lineFeedChar) {
			CSVData = fileData;
			lineFeedChar = lineFeedChar;
		}

		global Boolean hasNext() {
			return CSVData.length() > 1 ? true : false;
		}

		global String next() {
			String row;
			try {
				row = CSVData.subString(0, CSVData.indexOf(lineFeedChar));
				CSVData = CSVData.subString(CSVData.indexOf(lineFeedChar) + lineFeedChar.length(), CSVData.length());
			} catch (Exception e) {
				row = CSVData;
				CSVData = '';
			}

			return row;
		}

		global Iterator < string > Iterator() {
			return this;
		}
	}
}
