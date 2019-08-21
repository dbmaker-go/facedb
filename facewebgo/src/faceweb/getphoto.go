package main

import (
	"fmt"
	"net/http"
	"strconv"
)

func getPhoto(w http.ResponseWriter, req *http.Request) {
	defer func() {
		if xerr := recover(); xerr != nil {
			msg := fmt.Sprintf("%v", xerr)
			replyErr(w, msg)
		}
	}()

	idstr := req.FormValue("id")
	if idstr == "" {
		fmt.Printf("no id from client\n")
		w.Write([]byte(""))
		return
	}
	id, _ := strconv.ParseInt(idstr, 10, 32)

	photo, err := dbGetPhoto(int(id))
	if err != nil {
		fmt.Printf("can not get photo from face db: %v\n", err)
		w.Write([]byte(""))
		return
	}

	w.Header().Set("Content-Type", "image/jpeg")
	w.Write(photo)
	return
}
