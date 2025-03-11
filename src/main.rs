use gtk::{Button, CssProvider};
use gtk::gdk::Display;
use gtk::ScrolledWindow;
use integer_object::IntegerObject;

mod integer_object;
mod file_details;
mod update;

use file_details::FileDetails;
use update::Update;

use walkdir::WalkDir;
use std::{fmt, thread};

use notify::{watcher, RecursiveMode, Watcher};
use std::time::Duration;
use std::sync::mpsc::{channel, Sender};

use rand::prelude::*;

use adw::prelude::*;
use adw::{Application, ApplicationWindow, HeaderBar};
use gtk::{Box, Label, ListView, ListItem, Orientation, SignalListItemFactory, SingleSelection};

use gtk::gio;

fn watch(tx: Sender<Update>) {

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
    items.extend(WalkDir::new(path).into_iter().map(|entry| {
        FileDetails {
            path: entry.unwrap().into_path()
        }
    }));

    // Send the initial state.
    tx.send(Update::Set(items))
        .expect("Failed to send item upates.");

    // Blocking wait on changes; this needs to happen in a thread.
    loop {
        match watcher_rx.recv() {
            Ok(_) => {
                let set = Update::Set(WalkDir::new(path).into_iter().map(|entry| {
                    FileDetails {
                        path: entry.unwrap().into_path()
                    }
                }).collect());
                tx.send(set)
                    .expect("Failed to send item updates.");
            },
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
            }
            // Update::Insert(file, index) => {
            //     write!(f, "Insert({}, at index {})", file.path.display(), index)
            // }
            // Update::Remove(index) => {
            //     write!(f, "Remove(at index {})", index)
            // }
        }
    }
}

fn startup() {

    // Load custom styles.
    let provider = CssProvider::new();
    provider.load_from_string("
        #custom-data {
            background-color: magenta;
        }
    ");
    gtk::style_context_add_provider_for_display(
        &Display::default().expect("Could not connect to a display."),
        &provider,
        gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );

}

fn main() {

    let (tx, rx) = channel();
    thread::spawn(move || {
        watch(tx);
    });

    loop {
        match rx.recv() {
            Ok(event) => {
                println!("{}", event);
            },
            Err(e) => println!("watch error {:?}", e),
        }
    }

    return;

    let application = Application::builder()
        .application_id("uk.co.jbmorley.fileaway")
        .build();

    application.connect_startup(|_| startup());
    application.connect_activate(|app| {

        // List source.
        let vector: Vec<IntegerObject> = (0..10)
            .map(IntegerObject::new)
            .collect();

        let model = gio::ListStore::new::<IntegerObject>();
        model.extend_from_slice(&vector);

        let factory = SignalListItemFactory::new();
        factory.connect_setup(move |_, list_item| {
            let label = Label::new(None);
            list_item
                .downcast_ref::<ListItem>()
                .expect("Needs to be ListItem")
                .set_child(Some(&label));
        });
        factory.connect_bind(move |_, list_item| {
            let integer_object = list_item
                .downcast_ref::<ListItem>()
                .unwrap()
                .item()
                .and_downcast::<IntegerObject>()
                .unwrap();

            let label = list_item
                .downcast_ref::<ListItem>()
                .unwrap()
                .child()
                .and_downcast::<Label>()
                .unwrap();
            label.set_label(&integer_object.number().to_string());
        });

        let model_clone = model.clone();
        let selection_model = SingleSelection::new(Some(model_clone));
        let list_view = ListView::new(Some(selection_model), Some(factory));

        let scrolled_window = ScrolledWindow::builder()
            .hscrollbar_policy(gtk::PolicyType::Never)
            .propagate_natural_height(true)
            .propagate_natural_width(true)
            .min_content_width(300)
            .min_content_height(500)
            .kinetic_scrolling(false)
            .child(&list_view)
            .build();

        let button = Button::builder()
            .label("Cheese")
            .build();

        button.connect_clicked(move |_| {
            let item = IntegerObject::new(rand::rng().random());
            model.insert(0, &item);
        });

        // Content.
        let content = Box::new(Orientation::Vertical, 0);
        content.set_widget_name("custom-data");

        content.append(&HeaderBar::new());
        content.append(&scrolled_window);
        content.append(&button);

        let window = ApplicationWindow::builder()
            .application(app)
            .title("First App")
            .content(&content)
            .build();
        window.present();
        
    });

    application.run();
}
