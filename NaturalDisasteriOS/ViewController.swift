//
//  ViewController.swift
//  Safety First!
//
//  Created by Kevin Mo on 10/7/20.
//  Copyright © 2020 Kevin Mo. All rights reserved.
//

import UIKit
import CoreML
import Vision
import InstantSearchVoiceOverlay
import Speech


class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    @IBOutlet weak var myImageView: UIImageView!
    @IBOutlet weak var labelPredict: UILabel!
    var actualImage = UIImagePickerController()
    @IBOutlet weak var startStopBtn: UIButton!
    @IBOutlet weak var textView: UITextView!
    
    // Credit to Soonin Coding Challenge for speech code
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US")) //1
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    var lang: String = "en-US"
    
    // speech
    let voiceOverlay = VoiceOverlayController()
    
    @IBAction func importImage(_ sender: UIButton) {
        let image = UIImagePickerController()
        image.delegate = self
        
        image.sourceType = UIImagePickerController.SourceType.photoLibrary
        
        image.allowsEditing = false
        self.present(image, animated: true) {
            print("yessssssss")
        }
        
        actualImage = image
    }
    
    @IBAction func predictButton(_ sender: UIButton) {
        let ciImage = CIImage(image: myImageView.image!)
        let handler = VNImageRequestHandler(ciImage: ciImage!)
        do {
          try handler.perform([classificationRequest])
        } catch {
          print(error)
        }
    }
    
    
    
//    @IBAction func importImage(_ sender: Any) {
//        let image = UIImagePickerController()
//        image.delegate = self
//
//        image.sourceType = UIImagePickerController.SourceType.photoLibrary
//
//        image.allowsEditing = false
//        self.present(image, animated: true) {
//            print("yessssssss")
//        }
//
//        actualImage = image
////        guard let context = drawView.getViewContext(),
////          let inputImage = context.makeImage()
////          else { fatalError("Get context or make image failed.") }
////        // DONE: Perform request on model
//    }
//
//    @IBAction func predictButton(_ sender: UIButton) {
////        let inputImage = actualImage.makeImage()
////        let ciImage = CIImage(cgImage: myImageView as! CGImage)
//        let ciImage = CIImage(image: myImageView.image!)
//        let handler = VNImageRequestHandler(ciImage: ciImage!)
//        do {
//          try handler.perform([classificationRequest])
//        } catch {
//          print(error)
//        }
//    }
    
    
    // DONE: Define lazy var classificationRequest
    lazy var classificationRequest: VNCoreMLRequest = {
      // Load the ML model through its generated class and create a Vision request for it.
      do {
        let model = try VNCoreMLModel(for: NaturalDisasterClassifier().model)
        return VNCoreMLRequest(model: model, completionHandler: self.handleClassification)
      } catch {
        fatalError("Can't load Vision ML model: \(error).")
      }
    }()

    func handleClassification(request: VNRequest, error: Error?) {
      guard let observations = request.results as? [VNClassificationObservation]
        else { fatalError("Unexpected result type from VNCoreMLRequest.") }
      guard let best = observations.first
        else { fatalError("Can't get best result.") }

      DispatchQueue.main.async {
        self.labelPredict.text = "The Natural Disaster Is: " + best.identifier
        self.labelPredict.isHidden = false
        self.alertPopups(disasterText: best.identifier)
      }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            myImageView.image = image
        }
        
        else {
            print("yno")
            // error
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startStopBtn.layer.cornerRadius = 20
        startStopBtn.isEnabled = false  //2
        speechRecognizer?.delegate = self as? SFSpeechRecognizerDelegate  //3
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        SFSpeechRecognizer.requestAuthorization { (authStatus) in  //4
            
            var isButtonEnabled = false
            
            switch authStatus {  //5
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.startStopBtn.isEnabled = isButtonEnabled
            }
        }
        // Do any additional setup after loading the view.
    }
    
    @IBAction func startStopAct(_ sender: Any) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            startStopBtn.isEnabled = false
            startStopBtn.setTitle("Start Recording", for: .normal)
        } else {
            startRecording()
            startStopBtn.setTitle("Stop Recording", for: .normal)
        }
    }
    
    func startRecording() {
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
//            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                
                self.textView.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }
            
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.startStopBtn.isEnabled = true
                
                self.labelPredict.text = "The Natural Disaster Is: " + self.labelName()
                self.alertPopups(disasterText: self.labelName())
            }
            
            
        })
        
        print("hallo")
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        textView.text = "Say something, I'm listening!"
        
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            startStopBtn.isEnabled = true
        } else {
            startStopBtn.isEnabled = false
        }
    }
    
    func labelName() -> String {
        let mlModel = SpeechClassifier_1()
        var labelStr = ""
        
        do { // the ML connection and ability to predict
            print(self.textView.text)
            let prediction = try mlModel.prediction(Text: self.textView.text)
            labelStr = prediction.Label
        } catch {

        }
        
        return labelStr
    }
    
    func alertPopups(disasterText: String) {
        var alert = UIAlertController(title: "Default", message: "Default", preferredStyle: .alert)

        if (disasterText == "Cyclone") {
            alert = UIAlertController(title: "A " + disasterText + " is in your area!", message: "Find shelter immediately! Unplug everything in a residence and go to the sturdiest part of your house. Stay away from doors, and keep updated with the authorities in the area.", preferredStyle: .alert)
        }
        
        else if (disasterText == "Flood") {
            alert = UIAlertController(title: "A " + disasterText + " is in your area!", message: "Stay indoors if possible! If not, make sure you are above the flood water - in an indoor situation, go to the uppest floor of the house. Make sure to turn off anything electricity related.", preferredStyle: .alert)
        }
        
        else {
            alert = UIAlertController(title: "A " + disasterText + " is in your area!", message: "Find cover immediately! Duck under sturdy furniture, such as a desk or table. Stay away from windows and doors, and anything that could possibly fall on you.", preferredStyle: .alert)
        }
        
        alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))

        self.present(alert, animated: true)
    }
    
    


}



