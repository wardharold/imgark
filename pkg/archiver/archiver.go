// Package archiver provides the constructor and ReceiveAndProcess method for the archiver microservice.
// The archiver microservice is responsible for copying images whose lables match its target lable to
// Google Cloud Storage.
package archiver

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"strings"
	"time"

	"cloud.google.com/go/pubsub"
	"cloud.google.com/go/storage"
	minio "github.com/minio/minio-go"
	"github.com/wardharold/imgark/pkg/satokensource"
	"github.com/wardharold/imgark/pkg/sdlog"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	iam "google.golang.org/api/iam/v1"
	"google.golang.org/api/option"
)

// An Archiver compares its label to image labels it receives via pubsub.
// If there is a match the labeled image is copied to cloud storage.
type Archiver struct {
	bucket string
	label  string
	logger *sdlog.StackdriverLogger
	mc     *minio.Client
	sc     *storage.Client
	sub    *pubsub.Subscription
}

var (
	ctx = context.Background()
)

// New creates and initializes an Archiver. The archiver will use the specified serviceAccount
// to subscribe to the labeledTopic and write to the cloud storage bucket.
func New(logger *sdlog.StackdriverLogger, mc *minio.Client, projectID, serviceAccount, bucket, labeledTopic, subcription, targetlabel string) (*Archiver, error) {
	client, err := google.DefaultClient(ctx, iam.CloudPlatformScope, "https://www.googleapis.com/auth/iam")
	if err != nil {
		return nil, err
	}

	archiver := &Archiver{
		bucket: bucket,
		label:  targetlabel,
		logger: logger,
		mc:     mc,
	}

	ts := option.WithTokenSource(oauth2.ReuseTokenSource(nil, satokensource.New(client, logger, projectID, serviceAccount)))

	archiver.sc, err = storage.NewClient(ctx, ts)
	if err != nil {
		return nil, fmt.Errorf("storage client creation error: %+v", err)
	}

	pc, err := pubsub.NewClient(ctx, projectID, ts)
	if err != nil {
		return nil, fmt.Errorf("pubsub client creation error: %+v", err)
	}

	if archiver.sub, err = subscribe(pc, subcription, labeledTopic); err != nil {
		return nil, fmt.Errorf("subscription error: %+v", err)
	}

	return archiver, nil
}

// ReceiveAndProcess responds to messages from the labeledTopic by comparing the
// archiver's target label to each of the labels in the message. If there is a match
// the associated image is copied to the archiver's cloud storage bucket.
func (a Archiver) ReceiveAndProcess(ctx context.Context) {
	subid := a.sub.ID()

	err := a.sub.Receive(ctx, func(ctx context.Context, m *pubsub.Message) {
		bucket, object, labels, err := parseMessage(m.Data)
		if err != nil {
			a.logger.LogError("Bad message", err)
		} else {
			for _, label := range labels {
				if strings.Contains(label, a.label) {
					if err := writeToCloud(a.mc, a.sc, a.logger, a.bucket, bucket, object); err != nil {
						a.logger.LogError("Cloud write failed", err)
					}
					m.Ack()
					break
				}
			}
		}
	})
	switch err {
	case nil, context.Canceled:
		if err = a.sub.Delete(ctx); err != nil {
			a.logger.LogError(fmt.Sprintf("Unable to delete subscription: %s", subid), err)
		}
	default:
		a.logger.LogError("Unable to Receive", err)
	}
}

func parseMessage(msg []byte) (string, string, []string, error) {
	var df interface{}
	err := json.Unmarshal(msg, &df)
	if err != nil {
		return "", "", []string{}, err
	}

	location := df.(map[string]interface{})["location"]
	if location == nil || len(location.(string)) == 0 {
		return "", "", []string{}, fmt.Errorf("empty location field")
	}

	labels := df.(map[string]interface{})["labels"]
	if labels == nil || len(labels.([]interface{})) == 0 {
		return "", "", []string{}, fmt.Errorf("empty labels field")
	}

	locparts := strings.Split(location.(string), "/")
	if len(locparts) != 2 {
		return "", "", []string{}, fmt.Errorf("location must have format <bucket>/<object> [%s]", location.(string))
	}

	ls := []string{}
	for _, l := range labels.([]interface{}) {
		ls = append(ls, l.(string))
	}

	return locparts[0], locparts[1], ls, nil
}

func subscribe(pc *pubsub.Client, subscription, topic string) (*pubsub.Subscription, error) {
	sub := pc.Subscription(subscription)
	if sub == nil {
		return nil, fmt.Errorf("no such subscription: %s", subscription)
	}

	ok, err := sub.Exists(ctx)
	if err != nil {
		return nil, fmt.Errorf("cannot determine if subscription exists: %+v", err)
	}

	if !ok {
		sub, err = pc.CreateSubscription(ctx, subscription, pubsub.SubscriptionConfig{
			Topic:       pc.Topic(topic),
			AckDeadline: 60 * time.Second,
		})
		if err != nil {
			return nil, fmt.Errorf("cannot create subscription: %+v", err)
		}
	}

	return sub, nil
}

func writeToCloud(mc *minio.Client, sc *storage.Client, logger *sdlog.StackdriverLogger, cb, lb, o string) error {
	wc := sc.Bucket(cb).Object(o).NewWriter(ctx)
	wc.ContentType = "application/octet-stream"

	obj, err := mc.GetObject(lb, o, minio.GetObjectOptions{})
	if err != nil {
		return err
	}

	bs, err := ioutil.ReadAll(obj)
	if err != nil {
		return err
	}

	if _, err := wc.Write(bs); err != nil {
		return err
	}

	if err = wc.Close(); err != nil {
		return err
	}

	return nil
}
