use std::fmt;

use crate::file_details::FileDetails;

pub enum Update {
    Set(Vec<FileDetails>),
    // Insert(FileDetails, i64),
    // Remove(i64),
}

impl fmt::Display for Update {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Update::Set(files) => {
                write!(f, "Set({} files): [", files.len())?;
                for (i, file) in files.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?; // Add comma between entries
                    }
                    write!(f, "{}", file.path.display())?;
                }
                write!(f, "]") // Close the list
            } // Update::Insert(file, index) => {
              //     write!(f, "Insert({}, at index {})", file.path.display(), index)
              // }
              // Update::Remove(index) => {
              //     write!(f, "Remove(at index {})", index)
              // }
        }
    }
}
