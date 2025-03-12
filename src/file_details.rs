use std::path::PathBuf;

// TODO: This probably shouldn't be done here?
use gtk::glib::Boxed;

// TODO: Consider whether it makes sense to derive `Default` here.
#[derive(Default, Boxed, Clone)]
#[boxed_type(name = "FileDetailsBoxed")]
pub struct FileDetails {
    pub path: PathBuf,
}
