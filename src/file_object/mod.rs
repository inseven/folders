mod imp;

use glib::Object;
use gtk::glib;

use crate::file_details::FileDetails;

glib::wrapper! {
    pub struct FileObject(ObjectSubclass<imp::FileObject>);
}

impl FileObject {
    pub fn new(details: &FileDetails) -> Self {
        return Object::builder().property("details", details.path.clone()).build();
    }
}
