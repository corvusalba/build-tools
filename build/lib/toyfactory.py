# -*- python -*-
# ex: set syntax=python:

from buildbot.changes import filter
from buildbot.changes.gitpoller import GitPoller

from buildbot.schedulers.basic import SingleBranchScheduler
from buildbot.schedulers.forcesched import ForceScheduler

from buildbot.process.factory import BuildFactory

from buildbot.steps.source.git import Git
from buildbot.steps.shell import ShellCommand
from buildbot.steps.transfer import FileUpload

from buildbot.config import BuilderConfig

def configure(config):
    # pollers
    config['change_source'].append(GitPoller(
        'git@github.com:retran/toy-factory.git',
        workdir='gitpoller-workdir',
        branch='dev',
        pollinterval=60,
        project='toy-factory-dev'
    ))

    # schedulers
    config['schedulers'].append(SingleBranchScheduler(
        name="toy-factory-dev-ci",
        change_filter=filter.ChangeFilter(branch='dev'),
        treeStableTimer=None,
        builderNames=["toy-factory-linux-ci"],
        project='toy-factory-dev'))

    config['schedulers'].append(ForceScheduler(
        name="toy-factory-dev-ci-force",
        builderNames=["toy-factory-linux-ci"]))

    # factories
    linuxci = BuildFactory()

    workdir = './build/src/'

    linuxci.addStep(Git(
        repourl='git@github.com:retran/toy-factory.git',
        mode='full',
        method='clobber'))

    linuxci.addStep(ShellCommand(
        command=["mono", "paket.exe", "restore"],
        workdir=workdir))

    linuxci.addStep(ShellCommand(
        command=["xbuild", "CorvusAlba.ToyFactory.Linux.sln"],
        workdir=workdir))

    # factory.addStep(ShellCommand(command=["tar", "-zcvf", "toy-factory.tar.gz", "../bin"], workdir=wdir))
    # factory.addStep(FileUpload(slavesrc="toy-factory.tar.gz", masterdest="~/toy-factory.tar.gz", workdir=wdir))

    # builders
    config['builders'].append(BuilderConfig(
        name="toy-factory-linux-ci",
        slavenames=["linux"],
        factory=linuxci))
