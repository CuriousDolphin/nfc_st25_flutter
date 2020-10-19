package com.enerbrain.nfc_st25;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;


import android.app.PendingIntent;
import android.content.Intent;
import android.nfc.FormatException;
import android.nfc.NdefMessage;
import android.nfc.NdefRecord;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.Ndef;
import android.nfc.tech.NdefFormatable;
import android.os.AsyncTask;
import android.app.Activity;
import android.widget.TextView;
import android.widget.Toast;

import com.st.st25sdk.NFCTag;
import com.st.st25sdk.STException;
import com.st.st25sdk.STRegister;
import com.st.st25sdk.TagHelper;
import com.st.st25sdk.ndef.NDEFMsg;
import com.st.st25sdk.ndef.NDEFRecord;
import com.st.st25sdk.ndef.TextRecord;
import com.st.st25sdk.ndef.UriRecord;
import com.st.st25sdk.type5.st25dv.ST25DVTag;
import java.util.HashMap;
import java.util.List;


/** NfcSt25Plugin */
public class NfcSt25Plugin implements FlutterPlugin, MethodCallHandler,ActivityAware, NfcAdapter.ReaderCallback ,EventChannel.StreamHandler, TagDiscovery.onTagDiscoveryCompletedListener  {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private EventChannel tagChannel;
  private EventChannel.EventSink events;

  private  Activity activity;
  private NfcAdapter adapter;
  private ST25DVTag lastTag = null;
  private final int DEFAULT_READER_FLAGS = NfcAdapter.FLAG_READER_NFC_A | NfcAdapter.FLAG_READER_NFC_B | NfcAdapter.FLAG_READER_NFC_F | NfcAdapter.FLAG_READER_NFC_V;
  enum Action {
    READ_MEMORY_SIZE,
    READ_FAST_MEMORY,
    WRITE_MAIL_BOX,
    GET_INFO,
    GET_MAILBOX_INFO,
    READ_MAIL_BOX,
    RESET_MAIL_BOX,
    WRITE_NDEF_MESSAGE,

    READ_NDEF_MESSAGE

  };

  enum ActionStatus {
    ACTION_SUCCESSFUL,
    ACTION_FAILED,
    TAG_NOT_IN_THE_FIELD
  };




  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding){
    Log.i("nfc","onAttachedToActivity");
    activity=binding.getActivity();
   // binding.addOnNewIntentListener(this);
    adapter = NfcAdapter.getDefaultAdapter(activity);
  }
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    Log.i("nfc","onAttachedToEngine");
    channel = new MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "nfc_st25");
    tagChannel = new EventChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "nfc_st25/tags");

    channel.setMethodCallHandler(this);
    tagChannel.setStreamHandler(this);
  }
  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
  @Override
  public void onDetachedFromActivityForConfigChanges() {
    // TODO: the Activity your plugin was attached to was
    // destroyed to change configuration.
    // This call will be followed by onReattachedToActivityForConfigChanges().
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
    // TODO: your plugin is now attached to a new Activity
    // after a configuration change.
  }

  @Override
  public void onDetachedFromActivity() {
    Log.i("nfc","DETACH FROM ACTIVITY ");
    // TODO: your plugin is no longer associated with an Activity.
    // Clean up references.
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "getPlatformVersion":
        result.success("Android " + android.os.Build.VERSION.RELEASE);
        break;
      case "checkNfcAvailability":
        result.success(nfcIsEnabled());
        break;
      case "startReading":
        startReading();
        //startReadingWithForegroundDispatch();
        break;
      case "readMailbox":
        executeAsynchronousAction(Action.READ_MAIL_BOX,result,null);
        break;
      case "getMailboxInfo":
        executeAsynchronousAction(Action.GET_MAILBOX_INFO, result,null);
        break;
      case "writeMailbox":
        executeAsynchronousAction(Action.WRITE_MAIL_BOX,result,call.arguments);
        break;

      case "resetMailbox":
        executeAsynchronousAction(Action.RESET_MAIL_BOX,result,null);
        break;
      case "writeNDEF":
        executeAsynchronousAction(Action.WRITE_NDEF_MESSAGE,result,call.arguments);
        break;
      case "readNDEF":
        executeAsynchronousAction(Action.READ_NDEF_MESSAGE,result,call.arguments);
        break;


      default:
        result.notImplemented();
    }




  }





  @Override
  public void onTagDiscovered(Tag tag){
    Log.i("nfc","on TAG DISCOVERY "+ tag.getId());
    new TagDiscovery(this).execute(tag);

  }

  private void startReadingWithForegroundDispatch() {

    // adapter = NfcAdapter.getDefaultAdapter();
    adapter = NfcAdapter.getDefaultAdapter(activity);

    if (adapter == null) return;
    Intent intent = new Intent(activity.getApplicationContext(), activity.getClass());
    intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);

    PendingIntent pendingIntent = PendingIntent.getActivity(activity.getApplicationContext(), 0, intent, 0);
    String[][] techList = new String[][]{};
    Log.i("nfc","start reading foreground");
    adapter.enableForegroundDispatch(activity, pendingIntent, null, techList);
  }

  private void startReading() {
    adapter = NfcAdapter.getDefaultAdapter(activity);
    if (adapter == null) return;
    Bundle bundle = new Bundle();
    int flags = DEFAULT_READER_FLAGS;
    Log.i("nfc","start reading mode");
    adapter.enableReaderMode(activity, this, flags, bundle);
  }

  @Override
  public void onTagDiscoveryCompleted(NFCTag nfcTag, TagHelper.ProductID productId, STException error) {
    Log.i("nfc","ON DISCOVERY COMPLETED " );
    if (error != null) {
      Log.i("nfc","ON DISCOVERY ERROR " );
      eventError("DISCOVERY_FAILED",error.getMessage(),null);
      return;
    }

    if (nfcTag != null && productId.name().contains("PRODUCT_ST_ST25") ) {
      lastTag = (ST25DVTag) nfcTag;
      String name = nfcTag.getName();

      Log.i("nfc","ON DISCOVERY COMPLETED " + name);
      executeAsynchronousAction(Action.GET_INFO,null,null);
      /*try {
        HashMap<String, Boolean> mail_box = new HashMap<>();
        HashMap<String, Object> map = new HashMap<>();
        map.put("name",lastTag.getName());
        map.put("description",lastTag.getDescription());
        map.put("uid",lastTag.getUidString());

        // mail_box.put("mailbox_enabled",lastTag.isMailboxEnabled(false));
        // mail_box.put("msg_put_by_controller",lastTag.hasHostPutMsg(false));
        // mail_box.put("msg_put_by_nfc",lastTag.hasRFPutMsg(false));

        map.put("mail_box",mail_box);

        Log.i("nfc","ON DISCOVERY COMPLETED MAILBOX" + mail_box.toString());

        eventSuccess(map);


        executeAsynchronousAction(Action.GET_INFO,null);

      } catch (STException e) {
        e.printStackTrace();
        eventError("read failed","Discovery successful but failed to read the tag "+e.getMessage().toString(),null);
      }*/

    } else {
      eventError("DISCOVERY_FAILED","tag discovery failed or unsupported device",null);
      Log.i("nfc","tag discovery failed or unsupported device");
    }
  }


  private Boolean nfcIsEnabled() {
    NfcAdapter adapter = NfcAdapter.getDefaultAdapter(activity);
    if (adapter == null) return false;
    return adapter.isEnabled();
  }

  private void eventSuccess(final Object result) {
    Handler mainThread = new Handler(activity.getMainLooper());
    Runnable runnable = new Runnable() {
      @Override
      public void run() {
        if (events != null) {
          // Event stream must be handled on main/ui thread
          events.success(result);
        }
      }
    };
    mainThread.post(runnable);
  }

  private void eventError(final String code, final String message, final Object details) {
    Handler mainThread = new Handler(activity.getMainLooper());
    Runnable runnable = new Runnable() {
      @Override
      public void run() {
        if (events != null) {
          // Event stream must be handled on main/ui thread
          events.error(code, message, details);
        }
      }
    };
    mainThread.post(runnable);
  }

  @Override
  public void onListen(Object arguments, EventChannel.EventSink eventSink) {
    Log.i("nfc","stream on listen");
    events = eventSink;
  }

  @Override
  public void onCancel(Object arguments) {
    Log.i("nfc","stream on cancel");
     events =null;
  }


  private void executeAsynchronousAction(Action action,Result result,Object data) {
    Log.d("nfc", "Starting background action " + action);
    new myAsyncTask(action,result,data).execute();
  }
  class myAsyncTask extends AsyncTask<Void, Void, ActionStatus> {
    Result mResult;
    Action mAction;
    int memSizeInBytes;
    String resultStatus ="";
    byte[] mailBoxMsg=null;
    // data to write
    Object requestData = null;
    HashMap<String,Boolean> mailbox = null;
    NDEFMsg ndefMsg = null;


    HashMap<String, Object> tagMap = new HashMap<>();


    public myAsyncTask(Action action,Result result,Object data) {
      mAction = action;
      mResult = result;
      requestData = data;

    }

    void getInfo() throws STException {
      tagMap = new HashMap<>();
      tagMap.put("name",lastTag.getName());
      tagMap.put("description",lastTag.getDescription());
      tagMap.put("uid",lastTag.getUidString());
      tagMap.put("memory_size",lastTag.getMemSizeInBytes());

      HashMap<String, Boolean> mail_box = getMailboxInfo();

      tagMap.put("mail_box",mail_box);

    }

    HashMap<String,Boolean> getMailboxInfo() throws  STException {
      HashMap<String, Boolean> mail_box = new HashMap<>();
      mail_box.put("mailbox_enabled",lastTag.isMailboxEnabled(true));
      mail_box.put("msg_put_by_controller",lastTag.hasHostPutMsg(true));
      mail_box.put("msg_put_by_nfc",lastTag.hasRFPutMsg(true));
      mail_box.put("msg_miss_by_controller",lastTag.hasHostMissMsg(true));
      mail_box.put("msg_miss_by_nfc",lastTag.hasRFMissMsg(true));
      return mail_box;
    }


    /*void readMailbox() throws STException {
      boolean isFull=lastTag.hasRFPutMsg(true) || lastTag.hasHostPutMsg(true);
      if(isFull){
        int size = lastTag.readMailboxMessageLength();
        Log.d("nfc", "READ MSG LENGTH " + size);
        byte[] ris = lastTag.readMailboxMessage(0,size);
        msg = new String(ris);
        result = ActionStatus.ACTION_SUCCESSFUL;
      }else{
        result = ActionStatus.ACTION_FAILED;
        resultStatus="MAILBOX EMPTY";
      }
      getInfo();
    } */

    @Override
    protected ActionStatus doInBackground(Void... param) {
      ActionStatus result;
      // msgbox full
      boolean isFull;

      try {
        switch (mAction) {
          case READ_NDEF_MESSAGE:
            ndefMsg=lastTag.readNdefMessage();
            result = ActionStatus.ACTION_SUCCESSFUL;
            break;
          case WRITE_NDEF_MESSAGE:
            String str = (String) requestData;
            // Create a NDEFMsg
            NDEFMsg ndefMsg = new NDEFMsg();
            // Create a URI record containing http://www.st.com
            ///UriRecord uriRecord = new UriRecord(NDEF_RTD_URI_ID_HTTP_WWW, "st.com/st25");
            TextRecord textRecord = new TextRecord(str);
            // Add the record to the NDEFMsg
            // Add the record to the NDEFMsg
            ndefMsg.addRecord(textRecord);
            // Write the NDEFMsg into the tag
            lastTag.writeNdefMessage(ndefMsg);
            result = ActionStatus.ACTION_SUCCESSFUL;
            break;


          case GET_INFO:
            getInfo();
            result = ActionStatus.ACTION_SUCCESSFUL;
            break;


          case READ_MEMORY_SIZE:
            memSizeInBytes = lastTag.getMemSizeInBytes();
            // If we get to this point, it means that no STException occured so the action was successful
            result = ActionStatus.ACTION_SUCCESSFUL;
            break;
          case WRITE_MAIL_BOX:
            isFull=lastTag.hasRFPutMsg(true) || lastTag.hasHostPutMsg(true);
            if(!isFull){
              byte[] var =(byte[]) requestData;

              Log.i("nfc","WRITE MAILBOX GOING TO SEND "+var.toString());
              lastTag.writeMailboxMessage(var) ;// writeMailboxMessage(var);
              result = ActionStatus.ACTION_SUCCESSFUL;
            }else{
              {
                result = ActionStatus.ACTION_FAILED;
                resultStatus="MAILBOX is FULL";
              }
            }

            break;
          case READ_MAIL_BOX:

             isFull=lastTag.hasRFPutMsg(true) || lastTag.hasHostPutMsg(true);
            if(isFull){
              int size = lastTag.readMailboxMessageLength();
              Log.i("nfc", "READ MSG LENGTH " + size);
              byte[] ris = lastTag.readMailboxMessage(0,size);
             // mailBoxMsg = new String(ris);
              mailBoxMsg=ris;

              result = ActionStatus.ACTION_SUCCESSFUL;
            }else{
              result = ActionStatus.ACTION_FAILED;
              resultStatus="MAILBOX EMPTY";
            }

            break;
          case RESET_MAIL_BOX:
            lastTag.resetMailbox();
            result = ActionStatus.ACTION_SUCCESSFUL;
            break;
          case READ_FAST_MEMORY:

            // If we get to this point, it means that no STException occured so the action was successful
            result = ActionStatus.ACTION_SUCCESSFUL;
            break;
          case GET_MAILBOX_INFO:
            mailbox=getMailboxInfo();
            result = ActionStatus.ACTION_SUCCESSFUL;

            break;
          default:
            result = ActionStatus.ACTION_FAILED;
            break;
        }

      } catch (STException e) {
        switch (e.getError()) {
          case TAG_NOT_IN_THE_FIELD:
            result = ActionStatus.TAG_NOT_IN_THE_FIELD;
            break;
          default:
            e.printStackTrace();
            result = ActionStatus.ACTION_FAILED;
            break;
        }
      }
      return result;
    }
    @Override
    protected void onPostExecute(ActionStatus actionStatus) {
      switch(actionStatus) {
        case ACTION_SUCCESSFUL:
          switch (mAction) {
            case RESET_MAIL_BOX:
              mResult.success("");
              break;
            case READ_MAIL_BOX:
              Log.i("nfc", "READ MSG  " + mailBoxMsg);
              mResult.success(mailBoxMsg);
              break;
            case WRITE_MAIL_BOX:
              Log.i("nfc", "SUCCESSFUL WRITE MSG  " + requestData.toString());
              mResult.success("");
              break;
            case GET_INFO:
                Log.i("nfc","SUCCESFULL READ TAG "+ tagMap.toString());
                eventSuccess(tagMap);
              break;
            case GET_MAILBOX_INFO:
              Log.i("nfc","SUCCESFULL READ MAILBOX INFO "+ mailbox.toString());
              mResult.success(mailbox);
              break;
            case READ_NDEF_MESSAGE:
              String ris = "";
              try{
                ris = ndefMsg.getPayload();
              }catch(Exception e){
              }
              Log.i("nfc", "SUCCESSFUL READ NDEF MSG:  " + ris);
              mResult.success(ris);
              break;

            case WRITE_NDEF_MESSAGE:
              Log.i("nfc", "SUCCESSFUL WRITE NDEF STRING MSG:  " + requestData.toString());
              mResult.success("");
              break;
            case READ_MEMORY_SIZE:

              //mTagMemSizeTextView.setText(String.valueOf(memSizeInBytes));
              break;
          }
          break;

        case ACTION_FAILED:
          switch (mAction){
            case GET_INFO:
              eventError("UNABLE_TO_GET_INFO","failed to get tag info ",null);
              break;
            case READ_MAIL_BOX:
              mResult.error("UNABLE_TO_READ_MAILBOX",resultStatus.toString(),null);
              break;
            default:
              // TODO HANDLE ERROR HERE!
              if(mResult!=null)
                mResult.error("ACTION_FAILED",resultStatus,null);
              break;
          }

          break;

        case TAG_NOT_IN_THE_FIELD:
          Log.i("nfc", "ERROR  " + mAction + " TAG NOT IN THE FIELD");
          if(mAction.equals(Action.GET_INFO))
            eventError("TAG_NOT_IN_THE_FIELD","TAG_NOT_IN_THE_FIELD, unable to get info",null);
          else
            mResult.error("TAG_NOT_IN_THE_FIELD","TAG_NOT_IN_THE_FIELD",null);

          break;
      }

      return;
    }
  }


}
