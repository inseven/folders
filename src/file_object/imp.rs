use std::cell::RefCell;

use glib::Properties;
use gtk::glib;
use gtk::prelude::*;
use gtk::subclass::prelude::*;

use crate::file_details::FileDetails;

use std::path::PathBuf;

#[derive(Properties, Default)]
#[properties(wrapper_type = super::FileObject)]
pub struct FileObject {
    #[property(get, set)]
    details: RefCell<PathBuf>,
}

// The central trait for subclassing a GObject
#[glib::object_subclass]
impl ObjectSubclass for FileObject {
    const NAME: &'static str = "MyGtkAppFileObject";
    type Type = super::FileObject;
}

// Trait shared by all GObjects
#[glib::derived_properties]
impl ObjectImpl for FileObject {}
