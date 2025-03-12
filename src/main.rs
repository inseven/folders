use gtk::gdk::Display;
use gtk::CssProvider;
use gtk::ScrolledWindow;
use integer_object::IntegerObject;

mod file_details;
mod integer_object;
mod file_object;
mod update;

use file_details::FileDetails;
use crate::file_object::FileObject;
use update::Update;

use std::thread;
use walkdir::WalkDir;

use glib::clone;

use notify::{watcher, RecursiveMode, Watcher};
use std::sync::mpsc::channel;
use std::time::Duration;

use adw::prelude::*;
use adw::{Application, ApplicationWindow, HeaderBar};
use gtk::{Box, Label, ListItem, ListView, Orientation, SignalListItemFactory, SingleSelection};

use gtk::gio;

const APP_ID: &str = "uk.co.jbmorley.fileaway";

fn watch(tx: async_channel::Sender<Update>) {
    // Print the initial state.
    let path = "/home/jbmorley/Local/Files";

    // Watch for changes.
    let (watcher_tx, watcher_rx) = channel();
    let mut watcher = watcher(watcher_tx, Duration::from_millis(200)).unwrap();
    watcher
        .watch(path, RecursiveMode::Recursive)
        .expect("Failed to watch directory for changes.");

    // Keep a backing array.
    let mut items: Vec<FileDetails> = vec![];

    // Since we've started watching the file system, we can now safely query the file system.
    items.extend(WalkDir::new(path).into_iter().map(|entry| FileDetails {
        path: entry.unwrap().into_path(),
    }));

    // Send the initial state.
    tx.send_blocking(Update::Set(items))
        .expect("Failed to send item upates.");

    // Blocking wait on changes; this needs to happen in a thread.
    loop {
        match watcher_rx.recv() {
            Ok(_) => {
                let set = Update::Set(
                    WalkDir::new(path)
                        .into_iter()
                        .map(|entry| FileDetails {
                            path: entry.unwrap().into_path(),
                        })
                        .collect(),
                );
                tx.send_blocking(set).expect("Failed to send item updates.");
            }
            Err(e) => println!("watch error {:?}", e),
        }
    }
}

// The Swift version automatically keeps a live view up to date.
// Ultimately we need this to go through an SQLite database, but maybe there can be an in-memory
// solution in the short term.

// - FS watcher
// - Cached FS watcher
// - Smart view that basically reports array opertaions. add / remove / move / update
// - What does a view actually look like??

fn startup() {
    // Load custom styles.
    let provider = CssProvider::new();
    provider.load_from_string(
        "
        #custom-data {
            background-color: magenta;
        }
    ",
    );
    gtk::style_context_add_provider_for_display(
        &Display::default().expect("Could not connect to a display."),
        &provider,
        gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}

fn main() {
    // Data source.
    let model = gio::ListStore::new::<FileObject>();

    // File watcher.
    let (tx, rx) = async_channel::unbounded();
    thread::spawn(move || {
        watch(tx);
    });
    glib::spawn_future_local(clone!(
        #[weak]
        model,
        async move {
            while let Ok(event) = rx.recv().await {
                println!("{}", event);
                match event {
                    Update::Set(items) => {
                        let objects: Vec<FileObject> = items.iter()
                            .map(FileObject::new)
                            .collect();
                        model.remove_all();
                        model.extend_from_slice(&objects);
                    },
                };
            }
        }
    ));

    // Application.
    let application = Application::builder().application_id(APP_ID).build();
    application.connect_startup(|_| startup());
    application.connect_activate(move |app| {
        let factory = SignalListItemFactory::new();
        factory.connect_setup(move |_, list_item| {
            let label = Label::new(None);
            list_item
                .downcast_ref::<ListItem>()
                .expect("Needs to be ListItem")
                .set_child(Some(&label));
        });
        factory.connect_bind(move |_, list_item| {
            let file_object = list_item
                .downcast_ref::<ListItem>()
                .unwrap()
                .item()
                .and_downcast::<FileObject>()
                .unwrap();

            let label = list_item
                .downcast_ref::<ListItem>()
                .unwrap()
                .child()
                .and_downcast::<Label>()
                .unwrap();
            label.set_label(&file_object.details().to_string_lossy().to_string());
        });

        let selection_model = SingleSelection::new(Some(model.clone()));
        let list_view = ListView::new(Some(selection_model), Some(factory));

        let scrolled_window = ScrolledWindow::builder()
            .hscrollbar_policy(gtk::PolicyType::Never)
            .propagate_natural_height(true)
            .propagate_natural_width(true)
            .min_content_width(300)
            .min_content_height(500)
            .child(&list_view)
            .build();

        // Content.
        let content = Box::new(Orientation::Vertical, 0);
        content.set_widget_name("custom-data"); // Used to set the background color.

        content.append(&HeaderBar::new());
        content.append(&scrolled_window);

        let window = ApplicationWindow::builder()
            .application(app)
            .title("First App")
            .content(&content)
            .build();
        window.present();
    });

    application.run();
}
