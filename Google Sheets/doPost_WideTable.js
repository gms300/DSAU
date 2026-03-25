function processForm_WideTable(jsonString) {
    const data = JSON.parse(jsonString);
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName("Form Responses");
    
    // 1. Get the current headers from the first row
    const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
    
    // 2. Compute the counts (same logic as before)
    const individualCount = [data.name_2, data.name_2_2, data.name_2_3]
      .filter(name => name && name.toString().trim() !== "").length;
  
    const siblingCount = [data.name_3, data.name_3_2, data.name_3_3, data.name_3_4]
      .filter(name => name && name.toString().trim() !== "").length;
  
    // 3. Define the Map (Header Name : JSON Value/Computed Value)
    const fieldMap = {
      "First": data.text_4,
      "Last": data.text_5,
      "Email": data.email_1,
      "Phone": data.phone_1,
      "Street 1": data.address_1_street_address,
      "Street 2": data.address_1_address_line,
      "City": data.address_1_city,
      "State": data.address_1_state,
      "Zip": data.address_1_zip,
      "County": data.select_1,
      "Household Size": data.number_1,
      "Pregnant?": data.radio_1,
      "Marital Status": data.select_2,
      "Other Parent": data.text_3,
      "Individual Count": individualCount,
      "Individual 1 Name": data.name_2,
      "Individual 1 Birthdate": data.date_1,
      "Individual 1 Age Group": data.select_3,
      "Individual 1 Dianosis Type": data.select_4,
      "Individual 2 Name": data.name_2_2,
      "Individual 2 Birthdate": data.date_1_2,
      "Individual 2 Age Group": data.select_3_2,
      "Individual 2 Dianosis Type": data.select_4_2,
      "Individual 3 Name": data.name_2_3,
      "Individual 3 Birthdate": data.date_1_3,
      "Individual 3 Age Group": data.select_3_3,
      "Individual 3 Dianosis Type": data.select_4_3,
      "Sibling Count": siblingCount,
      "Sibling 1 Name": data.name_3,
      "Sibling 1 Birthdate": data.date_2,
      "Sibling 2 Name": data.name_3_2,
      "Sibling 2 Birthdate": data.date_2_2,
      "Sibling 3 Name": data.name_3_3,
      "Sibling 3 Birthdate": data.date_2_3,
      "Sibling 4 Name": data.name_3_4,
      "Sibling 4 Birthdate": data.date_2_4,
      "DATA": jsonString
    };
  
    // 4. Build the row to append based on the ACTUAL header order
    const newRow = headers.map(header => {
      // If the header exists in our map, return the value, otherwise return empty string
      return fieldMap.hasOwnProperty(header) ? (fieldMap[header] || "") : "";
    });
  
    // 5. Append the row
    sheet.appendRow(newRow);
  }