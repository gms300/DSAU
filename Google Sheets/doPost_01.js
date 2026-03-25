function doPost(e) {
    try {
      // 1. Parse the incoming JSON
      const data = JSON.parse(e.postData.contents);
      
      const ss = SpreadsheetApp.getActiveSpreadsheet();
      const destSheet = ss.getSheetByName("Clean Data");
  
      // 2. Get Destination Headers (Row 1)
      const destHeaders = destSheet.getRange(1, 1, 1, destSheet.getLastColumn()).getValues()[0];
      const newRow = new Array(destHeaders.length).fill("");
  
      // 3. Mapping: "Destination Header" : "Forminator ID"
      const mapping = {
        "First": "text_4",
        "Last": "text_5",
        "Email": "email_1",
        "Phone": "phone_1",
        "Street 1": "address_1_street_address",
        "Street 2": "address_1_address_line",
        "City": "address_1_city",
        "State": "address_1_state",
        "Zip": "address_1_zip",
        "County": "select_1",
        "Household Size": "number_1",
        "Pregnant?": "radio_1",
        "Marital Status": "select_2",
        "Other Parent": "text_3",
        "Individual Name": "name_2",
        "Individual Birthdate": "date_1",
        "Individual Age Group": "select_3",
        "Individual Dianosis Type": "select_4",
        "Sibling Name": "name_3",
        "Sibling Birthdate": "date_2"
      };
  
      // 4. Fill the row based on the header positions
      destHeaders.forEach((headerName, index) => {
        const cleanHeader = headerName.toString().trim();
        
        // Check if this is our special JSON debug column
        if (cleanHeader === "JSON") {
          newRow[index] = JSON.stringify(data);
          return; // Move to next header
        }
  
        const sourceKey = mapping[cleanHeader];
        if (sourceKey && data[sourceKey] !== undefined) {
          let value = data[sourceKey];
          
          // Auto-format dates
          if (cleanHeader.toLowerCase().includes("birthdate") && value) {
            const d = new Date(value);
            value = isNaN(d.getTime()) ? value : d;
          }
          
          newRow[index] = value;
        }
      });
  
      // 5. Append the data
      destSheet.appendRow(newRow);
  
      return true;
  
    } catch (err) {
      console.error("Error: " + err.toString());
      return false;
    }
  }