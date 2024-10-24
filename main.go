package main

import (
	"fmt"
	"log"
	"sync"
	"time"
)

type UserProfile struct {
	ID       int
	Comments []string
	Likes    int
	Friends  []int
}

func main() {
	start := time.Now()
	userProfile, err := handleGetUserProfile(10)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(userProfile)
	fmt.Println("fetching the user profile took", time.Since(start))
}

type Response struct {
	data any
	err  error
}

func handleGetUserProfile(id int) (*UserProfile, error) {
	var (
		respch = make(chan Response, 3)
		wg     = &sync.WaitGroup{}
	)
	// we are doing 3 request inside their own goroutine
	go getComments(id, respch, wg)
	go getLikes(id, respch, wg)
	go getFriends(id, respch, wg)
	// adding 3 to the waitgroup
	wg.Add(3)
	wg.Wait() // block until the wg counter == 0 we unblock
	close(respch)

	// keep ranging. But when to stop??
	userProfile := &UserProfile{}
	for resp := range respch {
		if resp.err != nil {
			return nil, resp.err
		}
		switch msg := resp.data.(type) {
		case int:
			userProfile.Likes = msg
		case []int:
			userProfile.Friends = msg
		case []string:
			userProfile.Comments = msg
		}
	}
	return userProfile, nil
}

func getComments(id int, respch chan Response, wg *sync.WaitGroup) {
	time.Sleep(time.Millisecond * 200)
	comments := []string{
		"Hey, that was great",
		"Yeah Buddy",
		"Ow, I didnt know that",
	}
	respch <- Response{
		data: comments,
		err:  nil,
	}
	// work is done
	wg.Done()
}

func getLikes(id int, respch chan Response, wg *sync.WaitGroup) {
	time.Sleep(time.Millisecond * 200)
	respch <- Response{
		data: 11,
		err:  nil,
	}
	// work is done
	wg.Done()
}

func getFriends(id int, respch chan Response, wg *sync.WaitGroup) {
	time.Sleep(time.Millisecond * 100)
	friendIds := []int{11, 34, 854, 455}
	respch <- Response{
		data: friendIds,
		err:  nil,
	}
	// work is done
	wg.Done()
}
