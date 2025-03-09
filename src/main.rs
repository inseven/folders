// use cursive::views::{Dialog, ListView, EditView};
// use cursive::views::{TextView};
use cursive::view::Scrollable;
use cursive::view::Resizable;
use cursive::With;
use gtk::builders::SingleSelectionBuilder;
use gtk::subclass::selection_model;
use gtk::ScrolledWindow;
use integer_object::IntegerObject;

mod integer_object;

// use std::fs;
use walkdir::WalkDir;

use notify::{Watcher, RecursiveMode, watcher};
use std::time::Duration;
use std::sync::mpsc::channel;

use adw::prelude::*;
use adw::{ActionRow, Application, ApplicationWindow, HeaderBar};
use gtk::{Box, Label, ListBox, ListView, ListItem, Orientation, SelectionMode, SignalListItemFactory, SingleSelection};
// use glib;
// use glib::Object;

use gtk::gio;

// So the logic looks a little like this:
//
// - Read the state.
// - Render the state.
// - Watch for changes.
//     - Apply the changes.
//     - Render the state.

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

fn main() {

    let application = Application::builder()
        .application_id("uk.co.jbmorley.fileaway")
        .build();

    application.connect_activate(|app| {

        // List source.
        let vector: Vec<IntegerObject> = (0..100_000)
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

        let selection_model = SingleSelection::new(Some(model));
        let list_view = ListView::new(Some(selection_model), Some(factory));

        let scrolled_window = ScrolledWindow::builder()
            .hscrollbar_policy(gtk::PolicyType::Never)
            .min_content_width(300)
            .child(&list_view)
            .build();

        // Row.
        // let row = ActionRow::builder()
        //     .activatable(true)
        //     .title("Click me")
        //     .build();
        // row.connect_activated(|_| {
        //     eprintln!("Clicked!");
        // });

        // // List.
        // let list = ListBox::builder()
        //     .margin_top(32)
        //     .margin_end(32)
        //     .margin_bottom(32)
        //     .margin_start(32)
        //     .selection_mode(SelectionMode::None)
        //     .css_classes(vec![String::from("boxed-list")])
        //     .build();
        // list.append(&row);

        // Content.
        let content = Box::new(Orientation::Vertical, 0);
        content.append(&HeaderBar::new());
        // content.append(&list);
        content.append(&scrolled_window);

        let window = ApplicationWindow::builder()
            .application(app)
            .title("First App")
            .content(&content)
            .build();
        window.present();
        
    });

    application.run();

  
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

    return;
    
    // let mut siv = cursive::default();
    // siv.add_layer(
    //     Dialog::new()
    //         .title("Files")
    //         .button("OK", |s| s.quit())
    //         .content(
    //             ListView::new()
    //                 .child("Name", EditView::new().fixed_width(10))
    //                 .with(|list| {
    //                     for i in 0..50 {
    //                         list.add_child(
    //                             &format!("Item {i}"),
    //                             EditView::new(),
    //                         );
    //                     }
    //                 })
    //                 .scrollable()
    //         )
    // );
    // // siv.add_layer(Dialog::around(TextView::new("Hello Dialog!"))
    // //     .title("Cursive")
    // //     .button("Quit", |s| s.quit()));
    // siv.run();
}
