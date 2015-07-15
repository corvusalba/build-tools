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

repositoryUri='git@github.com:retran/toy-factory.git',
workingDirectory='./build/src/'

def createLinuxCIFactory():
    f = BuildFactory()

    f.addStep(Git(
        repourl=repositoryUri,
        mode='full',
        method='clobber'))

    f.addStep(ShellCommand(
        command=["mono", "paket.exe", "restore"],
        workdir=workingDirectory))

    f.addStep(ShellCommand(
        command=["xbuild", "CorvusAlba.ToyFactory.Linux.sln"],
        workdir=workingDirectory))

    return linuxci

def configure(config):
    # pollers
    config['change_source'].append(GitPoller(
        repositoryUri,
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
        builderNames=["toy-factory-linux-ci"]))

    config['schedulers'].append(ForceScheduler(
        name="toy-factory-dev-ci-force",
        builderNames=["toy-factory-linux-ci"]))

    # builders
    config['builders'].append(BuilderConfig(
        name="toy-factory-linux-ci",
        slavenames=["linux"],
        factory=createLinuxCIFactory()))
