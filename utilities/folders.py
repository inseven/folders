#!/usr/bin/env python3

# Copyright (c) 2023-2025 Jason Morley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import logging
import os
import re
import shutil

import fastcommand


NAME_REGEX = re.compile(r"^(.+?)((\s+(\#\S+))*)$")
TAG_REGEX = re.compile(r"\s+\#(\S+)")


class TaggedPath(object):

    def __init__(self, path):
        dirname, basename = os.path.split(os.path.abspath(path))
        name, ext = os.path.splitext(basename)
        match = NAME_REGEX.match(name)
        if not match:
            exit(f"Failed to parse '{path}'.")
        id = match.group(1)
        tag_string =  match.group(2)
        tags = TAG_REGEX.findall(tag_string)
        self.dirname = dirname
        self.id = id
        self.tags = set(tags)
        self.ext = ext

    def __str__(self):
        tag_string = "".join([" #" + tag for tag in sorted(self.tags)])
        return os.path.join(self.dirname, self.id + tag_string + self.ext)

    def add_tag(self, tag):
        self.tags.add(tag)

    def remove_tag(self, tag):
        if tag not in self.tags:
            return
        self.tags.remove(tag)


def move_if(source_path, destination_path):
    source_path = os.path.abspath(source_path)
    destination_path = os.path.abspath(destination_path)
    if source_path == destination_path:
        return
    if os.path.exists(destination_path):
        raise FileExistsError(destination_path)
    logging.info("%s -> %s",
                 os.path.relpath(source_path),
                 os.path.relpath(destination_path))
    shutil.move(source_path, destination_path)


@fastcommand.command("add-tag", help="add tag to one-or-more files", arguments=[
    fastcommand.Argument("tag", help="tag to add"),
    fastcommand.Argument("path", nargs="+", help="path of file to update"),
])
def command_add_tag(options):
    for path in options.path:
        tagged_path = TaggedPath(path)
        tagged_path.add_tag(options.tag)
        move_if(path, str(tagged_path))


@fastcommand.command("remove-tag", help="remove tags from one-or-more files", arguments=[
    fastcommand.Argument("tag", help="tag to remove"),
    fastcommand.Argument("path", nargs="+", help="path of file to update"),
])
def command_remove_tag(options):
    for path in options.path:
        tagged_path = TaggedPath(path)
        tagged_path.remove_tag(options.tag)
        move_if(path, str(tagged_path))


@fastcommand.command("rename-tag", help="rename a tag for one-or-more files", arguments=[
    fastcommand.Argument("old", help="tag to rename"),
    fastcommand.Argument("new", help="new name"),
    fastcommand.Argument("path", nargs="+", help="path of file to update"),
])
def command_rename_tag(options):
    print(options.old, options.new)
    for path in options.path:
        tagged_path = TaggedPath(path)
        if not options.old in tagged_path.tags:
            continue
        tagged_path.remove_tag(options.old)
        tagged_path.add_tag(options.new)
        move_if(path, str(tagged_path))


def main():
    cli = fastcommand.CommandParser(description="Command-line conveniences for working with Folders")
    cli.use_logging(format="[%(levelname)s] %(message)s")
    cli.run()


if __name__ == "__main__":
    main()
