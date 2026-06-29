import importlib
import json
import os
import tempfile

import todo


def setup_function(_):
    fd, path = tempfile.mkstemp(suffix=".json")
    os.close(fd)
    os.remove(path)
    os.environ["TODO_STORE"] = path
    importlib.reload(todo)


# --- core add / done -------------------------------------------------------

def test_add_creates_todo():
    t = todo.add("write blog")
    assert t["text"] == "write blog"
    assert todo.load()[0]["text"] == "write blog"


def test_done_marks_complete():
    todo.add("ship it")
    todo.mark_done(1)
    assert todo.load()[0]["done"] is True


def test_due_is_persisted():
    todo.add("file taxes", due="2026-04-15")
    saved = todo.load()[0]
    assert saved.get("due") == "2026-04-15"


# --- storage layer ---------------------------------------------------------

def test_load_empty_when_store_missing():
    assert todo.load() == []
    assert todo.list_todos() == []


def test_save_load_roundtrip():
    data = [{"id": 1, "text": "a", "done": False}]
    todo.save(data)
    assert todo.load() == data
    # persisted as valid JSON on disk
    with open(os.environ["TODO_STORE"]) as f:
        assert json.load(f) == data


# --- add semantics ---------------------------------------------------------

def test_ids_increment_sequentially():
    todo.add("one")
    todo.add("two")
    todo.add("three")
    assert [t["id"] for t in todo.load()] == [1, 2, 3]


def test_new_todo_defaults_to_not_done():
    t = todo.add("default state")
    assert t["done"] is False


def test_add_without_due_has_no_due_key():
    t = todo.add("no due date")
    assert "due" not in t


# --- mark_done edge cases --------------------------------------------------

def test_mark_done_only_targets_matching_id():
    todo.add("first")
    todo.add("second")
    todo.mark_done(2)
    saved = todo.load()
    assert saved[0]["done"] is False
    assert saved[1]["done"] is True


def test_mark_done_nonexistent_id_is_noop():
    todo.add("lonely")
    todo.mark_done(999)  # should not raise
    assert todo.load()[0]["done"] is False


# --- CLI (main) ------------------------------------------------------------

def test_cli_add_then_list(capsys):
    todo.main(["add", "buy milk"])
    out = capsys.readouterr().out
    assert "added #1: buy milk" in out

    todo.main(["list"])
    out = capsys.readouterr().out
    assert "[ ] #1 buy milk" in out


def test_cli_done_then_list_shows_x(capsys):
    todo.main(["add", "walk dog"])
    capsys.readouterr()
    todo.main(["done", "1"])
    assert "done #1" in capsys.readouterr().out

    todo.main(["list"])
    assert "[x] #1 walk dog" in capsys.readouterr().out


def test_cli_add_with_due_renders_in_list(capsys):
    todo.main(["add", "file taxes", "--due", "2026-04-15"])
    capsys.readouterr()
    todo.main(["list"])
    out = capsys.readouterr().out
    assert "file taxes (due 2026-04-15)" in out
