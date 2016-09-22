#!/usr/bin/env python

from __future__ import print_function

import web
import json
import getopt
import sys
import traceback
import smtplib
from email.mime.text import MIMEText

urls = ('/.*', 'hooks')
app = web.application(urls, globals())


def sendmail(subject, body):
    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = 'autobuilder@openturns.org'
    msg['To'] = 'commits@openturns.org'
    #msg['To'] = 'schueller@phimeca.com'
    server = smtplib.SMTP('localhost')
    server.sendmail(msg['From'], [msg['To']], msg.as_string())
    server.quit()
    print('sent mail:', msg['To'])

class hooks:
    def POST(self):
        data = web.data()
        try:
            payload = json.loads(data)
            print('received json:')
            print(json.dumps(payload, indent=4, sort_keys=False))
            repo = payload['repository']['full_name']
            print('repo:', repo)

            autobuilder_probe_dir = '/var/autobuilder/openturns/'
            probe_base = autobuilder_probe_dir + repo.replace('/','%')
            probe = None

            head_commit = payload.get('head_commit')
            if head_commit is not None:
                sha = head_commit.get('id')
                if sha is not None:
                    probe = probe_base + '%commit%' + sha
                    obj = repo+'/commit/'+sha[:7]
                    sendmail(obj, 'https://github.com/'+obj)

            pull = payload.get('pull_request')
            if pull is not None and pull.get('state') == 'open':
                pull_number = pull.get('number')
                pull_title = pull.get('title')
                if (pull_number is not None) and (pull_title is not None):
                    probe = probe_base + '%pull%' + str(pull_number)
                    sendmail(repo+'/pull/'+str(pull_number)+' ('+pull_title+')', 'https://github.com/'+repo+'/pull/'+str(pull_number)+' ('+pull_title+')')

            ref = payload.get('ref')
            if ref is not None:
                ref_type = payload.get('ref_type')
                if ref_type == 'tag':
                    probe = probe_base + '%tag%' + ref
                    sendmail(repo+'/tag/'+ref, 'https://github.com/'+repo+'/releases/tag/'+ref)

            print('probe:', probe)
            if probe is not None and not 'openturns%openturns%commit' in probe:
                open(probe,'w').close()
        except Exception, err:
            print(traceback.format_exc())
            print('failed to process data:', data)
        return 'OK'
      
    def GET(self):
        return 'OK'

if __name__ == '__main__':
    print('started')
    app.run()

