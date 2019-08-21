package main

import (
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"path"
	"strconv"
	"strings"
)

func registerFace(w http.ResponseWriter, req *http.Request) {
	defer func() {
		if xerr := recover(); xerr != nil {
			msg := fmt.Sprintf("%v", xerr)
			replyErr(w, msg)
		}
	}()

	log.Printf("======/register: %v =====\n", req.Method)
	b64img := req.PostFormValue("img")
	if b64img == "" {
		replyErr(w, "not found image")
		return
	}
	// data:image/png;base64,
	start := strings.Index(b64img, "base64,")
	if start <= 0 || start+7 >= len(b64img) {
		replyErr(w, "invalid image header")
		return
	}
	imgbuf := b64img[start+7:]
	img, err := base64.StdEncoding.DecodeString(imgbuf)
	if err != nil {
		replyErr(w, "invalid image:"+err.Error())
		return
	}

	name := req.PostFormValue("name")

	person, err := dbInsFace(name, img)
	if err != nil {
		replyErr(w, "insert error:"+err.Error())
		return
	}

	replyOK(w, person)
	return
}

func genUid() (int64, error) {
	var uid int64 = 0
	if files, err := ioutil.ReadDir(imgroot + "/registered"); err != nil {
		return -1, err
	} else {
		for _, f := range files {
			extname := path.Ext(f.Name())
			i, err := strconv.ParseInt(strings.TrimSuffix(f.Name(), extname), 10, 32)
			if err != nil {
				return -1, err
			}
			if uid < i {
				uid = i
			}
		}
	}
	uid++
	return uid, nil
}
