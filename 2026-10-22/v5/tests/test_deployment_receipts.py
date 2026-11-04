import copy
import unittest
from host_app.music_project import MusicProject,Song,Note,Patch,Section
from host_app.deployment import DeploymentSession


def catalog(project):
    return [dict(kind=kind,slot=slot,ready=True,resource_id=item.resource_id,revision=item.revision)
            for kind,items in ((0,project.songs),(1,project.patches)) for slot,item in enumerate(items)]


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.project=MusicProject(songs=[Song(notes=[Note(0,480,60)],sections=[Section(timbres=[2,0,0,0])])],patches=[Patch()])
        self.session=DeploymentSession();self.snapshot=self.session.prepare(self.project);self.directory=catalog(self.snapshot)
        self.session.accept(self.snapshot,self.directory)
    def test_undo_branch_same_revision_is_not_synced(self):
        song=self.project.songs[0];self.assertIsNotNone(self.session.song_match(song,self.project,self.directory))
        song.notes[0].pitch=64
        self.assertIsNone(self.session.song_match(song,self.project,self.directory))
        song.notes[0].pitch=60
        self.assertIsNotNone(self.session.song_match(song,self.project,self.directory))
    def test_adsr_dependency_invalidates_song_even_without_wave_change(self):
        self.project.patches[0].attack+=1
        self.assertIsNone(self.session.song_match(self.project.songs[0],self.project,self.directory))
    def test_publication_revision_never_rewinds_with_edit(self):
        old=copy.deepcopy(self.project);next_snapshot=self.session.prepare(self.project,self.directory)
        rolled_back=self.session.prepare(old,self.directory)
        self.assertGreater(rolled_back.songs[0].revision,next_snapshot.songs[0].revision)
    def test_reconnect_does_not_trust_directory_identity_alone(self):
        self.session.reset();self.assertIsNone(self.session.song_match(self.project.songs[0],self.project,self.directory))
    def test_partial_commit_cannot_create_receipt(self):
        with self.assertRaises(ValueError):self.session.accept(self.snapshot,self.directory[:1])
        self.assertFalse(self.session.receipts)

if __name__=='__main__':unittest.main()
