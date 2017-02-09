/*
 * CsvWriter.cpp
 *
 *  implementation of some functions
 *  defined in CsvWriter.h
 */

#include "CsvWriter.h"

namespace std {

CsvWriter::CsvWriter() {
	// constructor
	f_currentLine = new struct t_lines;
	f_firstLine = new struct t_lines;
	f_currentLine = NULL;
	f_firstLine = NULL;
	f_lineCount = 0;
}

void CsvWriter::writeToCSV(string filename) {
	//writes all lines to the given file
	string fname = filename;
	t_lines *current;
	current = new struct t_lines;
	current = f_firstLine;
	//adding extension to filename
	fname.append(".csv");
	//creating  NULL-terminated c-String
	ofstream csvFile (fname.c_str());
	//write lines to file
	if (csvFile.is_open())
	{
		while(current != NULL)
		{
			//writing content from given line to file
			csvFile << current->content;
			csvFile << "\n";
			current = current->next;
		}
	    csvFile.close();
	}
	else cout << "Unable to open file";
	free(current);
	std::cout<<"Log was written to "<<fname<<"\n" ;
}

void CsvWriter::addLineString(string s) {
	//adds new line to the list
	t_lines *newLine;
	std::stringstream sstrm;
	newLine = new struct t_lines;
	newLine->content = "";
	newLine->next = NULL;
	//creates new line from given array
	sstrm << s.c_str()<<",";
	newLine->content = (sstrm.str());
	//checks if at least one line exists
	if (f_firstLine == NULL) {
		f_firstLine = newLine;
		f_currentLine = newLine;
	} else {
		//else just adds line
		f_currentLine->next=newLine;
		f_currentLine = newLine;
	}
	f_lineCount ++;
}


CsvWriter::~CsvWriter() {
	free (f_firstLine);
	free (f_currentLine);
}

} /* namespace std */
