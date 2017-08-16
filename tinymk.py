# TinyMk
# A miniature Makefile alternative
#
# Copyright (c) 2017 Ryan Gonzalez
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

__all__ = ['lock', 'add_category', 'task', 'ptask', 'need_to_update',
           'digest_update', 'qinvoke', 'invoke', 'pinvoke', 'qpinvoke',
           'cinvoke', 'run', 'run_d', 'main', 'DBManager', 'file_digest']
__version__ = 0.4


import sys, os, subprocess, shlex, traceback, re, sqlite3, hashlib, warnings
from multiprocessing import Process, Lock
from collections import OrderedDict
from contextlib import closing


lock = Lock()


if sys.version_info.major >= 3:
    from shlex import quote
else:
    from pipes import quote

def quote_cmd(x):
    return ' '.join(map(quote, x))


if hasattr(hashlib, 'blake2b'):
    if sys.maxsize > 2**32:
        default_hash = hashlib.blake2b
    else:
        default_hash = hashlib.blake2s
else:
    default_hash = hashlib.sha256


class Category(object):
    def __init__(self, name):
        self.content = OrderedDict()
        self.name = name
        self.f = None

    def __getitem__(self, x): return self.content[x]
    def __setitem__(self, x, v): self.content[x] = v
    def __contains__(self, x): return x in self.content
    def __len__(self): return len(self.content)

    def __call__(self, *args, **kw):
        if self.f is None:
            raise Exception("Category '%s' cannot be run" % self.name)
        self.f(*args, **kw)


class DBManager(object):
    path = '.tinymk.db'
    connection = None


categories = {}
tasks = {}


def recursive_index(x, args):
    if not args:
        return x
    cur, rest = args[0], args[1:]
    return recursive_index(x[cur], rest)


def raise_none(exc):
    if sys.version_info.major == 2:
        exec('raise exc')
    else:
        exec('raise exc from None')


def _add_category(name, replace=False):
    if replace and ':' not in name:
        categories[name] = Category(name)
        return

    current = categories
    catlist = name.split(':')
    for i, x in enumerate(catlist):
        if x not in current:
            current[x] = Category(':'.join(catlist[:i+1]))
        current = current[x]


def get_category(name, create=False):
    category_str, name = name.rsplit(':', 1)
    if create:
        _add_category(category_str)

    try:
        cat = recursive_index(categories, category_str.split(':'))
    except KeyError:
        raise_none(Exception("Non-existent category '%s'" % category_str))

    return name, cat


def add_category(name):
    warnings.warn('add_category is deprecated')
    _add_category(name, True)


def task(tname=None):
    def _f(f):
        name = tname if tname is not None else f.__name__

        if ':' in name:
            name, bottom = get_category(name, True)
            if not name:
                name = f.__name__
            if name in bottom and isinstance(bottom[name], Category):
                bottom[name].f = f
            else:
                bottom[name] = f
        else:
            tasks[name] = f
        return f

    return _f


def ptask(pattern, outs, deps, category=None):
    if isinstance(outs, str):
        outs = shlex.split(outs)
    if isinstance(deps, str):
        deps = shlex.split(deps)

    assert '%' in pattern
    rpat = re.compile(re.escape(pattern).replace(r'\%', '(.+?)'))
    res = []

    for dep in deps:
        fdep = rpat.match(dep)
        assert fdep
        out_res = []

        for out in outs:
            assert out.count('%') <= rpat.groups
            pos = 1
            while '%' in out:
                out = out.replace('%', fdep.group(pos), 1)
                pos += 1
            out_res.append(out)

        res.append((tuple(out_res), dep))

    def _f(f):
        def mkfunc(outs, dep):
            return lambda *args, **kw: f(outs, dep, *args, **kw)

        for outs, dep in res:
            func = mkfunc(outs, dep)
            for out in outs:
                task('%s:%s' % (category, out) if category else out)(func)

    return _f


def extract_tasks(n, x):
    res = OrderedDict()

    for k, v in x:
        name = '%s:%s' % (n, k) if n else k
        if isinstance(v, Category):
            if v.f is not None:
                res[name] = v.f
            res.update(extract_tasks(name, v.content.items()))
        else:
            res[name] = v

    return res


def need_to_update(outs, deps):
    if isinstance(outs, str):
        outs = shlex.split(outs)
    if isinstance(deps, str):
        deps = shlex.split(deps)

    if not all(map(os.path.exists, outs)):
        return True
    oldest_out = min(map(os.path.getmtime, outs))
    newest_dep = max(map(os.path.getmtime, deps))

    return newest_dep > oldest_out


def file_digest(fpath, hash=default_hash):
    h = hash()

    with open(fpath, 'rb') as f:
        buf = f.read(1024)
        while buf:
            h.update(buf)
            buf = f.read(1024)

    return h.hexdigest()


def digest_update(_, deps):
    if isinstance(deps, str):
        deps = shlex.split(deps)
    do_update = False

    connection = DBManager.connection
    cursor = connection.cursor()
    cursor.execute('CREATE TABLE IF NOT EXISTS hashes (path text, hash text)')

    for dep in deps:
        cursor.execute('SELECT hash FROM hashes WHERE path=?', (dep,))
        row = cursor.fetchone()

        if row is None:
            do_update = True
            cursor.execute('INSERT INTO hashes VALUES (?, ?)',
                           (dep, file_digest(dep)))
        else:
            current = file_digest(dep)
            old = row[0]
            if old != current:
                do_update = True
                cursor.execute('UPDATE hashes SET hash=? WHERE path=?',
                               (current, dep))

    connection.commit()
    return do_update


def qinvoke(name, *args, **kw):
    if ':' in name:
        iname, target = get_category(name)
    else:
        iname = name
        target = tasks

    if not iname:
        target(*args, **kw)
    elif not isinstance(target, Category) and target is not tasks:
        raise Exception("Target '%s' is not a category" % name)
    elif iname not in target:
        raise Exception("Non-existent target '%s'" % name)
    else:
        target[iname](*args, **kw)


def invoke(name, *args, **kw):
    with lock:
        print('Running task %s...' % name)
    qinvoke(name, *args, **kw)


def pinvoke(*args, **kw):
    p = Process(target=invoke, args=args, kwargs=kw)
    p.start()
    return p


def qpinvoke(*args, **kw):
    p = Process(target=qinvoke, args=args, kwargs=kw)
    p.start()
    return p


def cinvoke(category_str, invoker=invoke):
    category = recursive_index(categories, category_str.split(':'))
    for x in extract_tasks(category_str, category.content.items()):
        invoker(x)


def run(cmd, write=True, shell=False, get_output=False, **kw):
    if write:
        with lock:
            if isinstance(cmd, str):
                print(cmd)
            else:
                print(quote_cmd(cmd))

    if isinstance(cmd, str) and not shell:
        cmd = shlex.split(cmd)
    if get_output:
        kw.update({'stdout': subprocess.PIPE, 'stderr': subprocess.PIPE})

    p = subprocess.Popen(cmd, shell=shell, **kw)
    p.wait()
    if p.returncode != 0:
        sys.exit("command '%s' returned exit status %d" % (cmd[0],
                                                           p.returncode))
    if get_output:
        return p.communicate()


def run_d(outs, deps, cmd, func=need_to_update, **kw):
    if func(outs, deps):
        run(cmd, **kw)


usage_str = 'usage: %s [-h|--help] [--task-help] <task> [<args>]' % sys.argv[0]

help_str = usage_str+'''

-h, --help : Show this help screen

--task-help : Show info about invoking tasks

<task> : Run a task(use --task-help for more info)

<args> : Arguments for the task
'''

task_str = '''
Tasks are organized into groups called categories. For example, this task name:

    a:b:c

is referring to the task `c` inside the category `b` inside the category `a`.

If you do this:

    a:b:?

the tasks belonging to the category `b` inside the category `a` will be printed.

If you do this:

    a:b:c?

it will print information about the task `c` inside `b` inside `a`.
'''.strip()


def print_tasks(tasks):
    if tasks:
        longest = max(map(len, tasks))

    for name, t in tasks.items():
        if t.__doc__ is not None:
            print('%s %s' % (name.ljust(longest), t.__doc__))
        else:
            print('%s' % name)


def main(no_warn=False, default=None):
    if not no_warn:
        warnings.simplefilter('default')

    if '-h' in sys.argv or '--help' in sys.argv:
        sys.stdout.write(help_str)
        sys.exit()
    elif '--task-help' in sys.argv:
        print(task_str.replace('\n\n', '\n'))
        sys.exit()
    elif len(sys.argv) < 2 and default is None:
        sys.stderr.write('invalid number of args\n')
        sys.exit(usage_str)

    task = sys.argv[1] if len(sys.argv) >= 2 else default
    if task == '?':
        all_tasks = tasks.copy()
        all_tasks.update(extract_tasks('', categories.items()))
        print('Tasks:\n')
        print_tasks(all_tasks)
        sys.exit()
    elif task.endswith(':?'):
        _, category = get_category(task)
        cname = task[:-2]
        print('Tasks in category %s:\n' % cname)
        print_tasks(extract_tasks(task[:-2], category.content.items()))
        sys.exit()

    args = sys.argv[2:]
    kw = {}
    for i, arg in enumerate(args[:]):
        if '=' in arg:
            k, v = arg.split('=')
            kw[k] = v
            del args[i]

    try:
        DBManager.connection = sqlite3.connect(DBManager.path)
        qinvoke(task, *args, **kw)
    except SystemExit as ex:
        sys.exit(ex.code)
    # Don't eat KeyboardInterrupt
    except KeyboardInterrupt:
        sys.exit()
    except:
        sys.stderr.write(
            'Exception occured during excecution of build script!\n')
        traceback.print_exc()
        sys.exit(1)
