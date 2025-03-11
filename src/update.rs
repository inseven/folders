use crate::file_details::FileDetails;

pub enum Update {
    Set(Vec<FileDetails>),
    // Insert(FileDetails, i64),
    // Remove(i64),
}
