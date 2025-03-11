use gtk::{Button, CssProvider};
use gtk::gdk::Display;
use gtk::ScrolledWindow;
use integer_object::IntegerObject;

mod integer_object;

use walkdir::WalkDir;

use notify::{Watcher, RecursiveMode, watcher};
use std::time::Duration;
use std::sync::mpsc::channel;

use rand::prelude::*;

use adw::prelude::*;
use adw::{Application, ApplicationWindow, HeaderBar};
use gtk::{Box, Label, ListView, ListItem, Orientation, SignalListItemFactory, SingleSelection};

use gtk::gio;

fn update(path: &str) {

    // List the directory.
    let paths = WalkDir::new(path);
    
    // Clear the screen and set the cursor to 1,1.
    print!("{esc}[2J{esc}[1;1H", esc = 27 as char);

    // Print the output.
    for path in paths {
        let dir = path.unwrap();
        println!("{:?}", dir.path());
    }
}

fn watch() {

    // Print the initial state.
    let path = "/home/jbmorley/Downloads";
    update(path);

    // Watch for changes.
    let (tx, rx) = channel();
    let mut watcher = watcher(tx, Duration::from_millis(200)).unwrap();
    watcher.watch(path, RecursiveMode::Recursive).unwrap();

    // Blocking wait on changes.
    loop {
        match rx.recv() {
            Ok(event) => {
                println!("{:?}", event);
                update(path);
            },
            Err(e) => println!("watch error {:?}", e),
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
