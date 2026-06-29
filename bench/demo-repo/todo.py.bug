import argparse
import json
import os

STORE = os.environ.get("TODO_STORE", "todos.json")


def load():
    if not os.path.exists(STORE):
        return []
    with open(STORE) as f:
        return json.load(f)


def save(todos):
    with open(STORE, "w") as f:
        json.dump(todos, f, indent=2)


def add(text, due=None):
    todos = load()
    todo = {"id": len(todos) + 1, "text": text, "done": False}
    # BUG: `due` is accepted but never written onto the todo.
    todos.append(todo)
    save(todos)
    return todo


def mark_done(todo_id):
    todos = load()
    for t in todos:
        if t["id"] == todo_id:
            t["done"] = True
    save(todos)


def list_todos():
    return load()


def main(argv=None):
    parser = argparse.ArgumentParser(prog="todo")
    sub = parser.add_subparsers(dest="cmd")
    p_add = sub.add_parser("add")
    p_add.add_argument("text")
    p_add.add_argument("--due", default=None)
    p_done = sub.add_parser("done")
    p_done.add_argument("id", type=int)
    sub.add_parser("list")
    args = parser.parse_args(argv)

    if args.cmd == "add":
        t = add(args.text, due=args.due)
        print(f"added #{t['id']}: {t['text']}")
    elif args.cmd == "done":
        mark_done(args.id)
        print(f"done #{args.id}")
    elif args.cmd == "list":
        for t in list_todos():
            mark = "x" if t["done"] else " "
            due = f" (due {t['due']})" if t.get("due") else ""
            print(f"[{mark}] #{t['id']} {t['text']}{due}")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
