package main

import (
	"io/ioutil"
	"testing"
)

func TestSearchFace(t *testing.T) {

	img, err := ioutil.ReadFile("/home/dbsql/photo/yaoming4.jpg")
	if err != nil {
		t.Fatal(err)
	}

	p, found, err := dbSearchFace(img, 0.38)
	if err != nil {
		t.Fatal(err)
	}

	if !found {
		t.Error("not found similar face")
	}

	t.Logf("found similar face: %d, %s, %v\n", p.Id, p.Name, p.Dist)

	dbSearchFace(img, 0.4)
}

func TestInsertFace(t *testing.T) {
	img, err := ioutil.ReadFile("/home/dbsql/photo/yaoming5.jpg")
	if err != nil {
		t.Fatal(err)
	}

	p, err := dbInsFace("yaoming5", img)
	if err != nil {
		t.Fatal(err)
	}

	if p.Id <= 0 {
		t.Error("insert error")
	}
	t.Log("insert ok:", p.Id, p.Name)

	p2, found, err2 := dbSearchFace(img, 0.38)
	if err2 != nil {
		t.Fatal(err)
	}
	if !found {
		t.Error("not found ", p.Id, p.Name)
	}
	t.Log("found ", p2.Id, p2.Name, p2.Dist)
}
