/*
 * CsvWriter.h
 *
 *  header for csv class
 */

#ifndef CSVWRITER_H_
#define CSVWRITER_H_

#include <string>
#include <iostream>
#include <sstream>
#include <fstream>
#include <stdlib.h>

namespace std {

	struct t_lines{
		//actuall content of this line/**/
		string content;
		//pointer to next line
		struct t_lines *next;
	};

	class CsvWriter {
	private:
		t_lines* f_firstLine;
		t_lines* f_currentLine;
		int f_lineCount;

	public:
		CsvWriter();
		void writeToCSV(string filename);
		template<typename T>
		void addLineValues(T arr, int arrLen);
		void addLineString(string s);
	virtual ~CsvWriter();
	};

} /* namespace std */

template<typename T>
inline void std::CsvWriter::addLineValues(T arr, int arrLen) {
	//adds new line to the list
	t_lines *newLine;
	std::stringstream sstrm;
	newLine = new struct t_lines;
	newLine->content = "";
	newLine->next = NULL;
	//creates new line from given array
	for (int x = 0; x <= arrLen-1; x++){
		sstrm << arr[x]<<",";
	}
	newLine->content = (sstrm.str());
	//checks if at least one line exists
	if (f_firstLine == NULL) {
		//if not, first line gets set
		f_firstLine = newLine;
		f_currentLine = newLine;
	} else {
		//if so, just adds line
		f_currentLine->next=newLine;
		f_currentLine = newLine;
	}
	f_lineCount ++;
}

#endif /* CSVWRITER_H_ */
